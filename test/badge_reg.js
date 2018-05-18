"use strict";

const BadgeReg = artifacts.require("./BadgeReg.sol");

contract("BadgeReg", accounts => {
  const assertThrowsAsync = async (fn, msg) => {
    try {
      await fn();
    } catch (err) {
      assert(err.message.includes(msg), "Expected error to include: " + msg);
      return;
    }
    assert.fail("Expected fn to throw");
  };

  const address = accounts[0];
  const owner = accounts[0];
  const name = "awesome";

  it("should allow registering a new badge", async () => {
    const badgeReg = await BadgeReg.deployed();

    const watcher = badgeReg.Registered();

    // the registration requires a fee of 1 ETH
    await badgeReg.register(address, name, { value: web3.toWei("1", "ether") });

    // if successful the contract should emit a `Registered` event
    const events = await watcher.get();

    const id = 0;

    assert.equal(events.length, 1);
    assert.equal(web3.toUtf8(events[0].args.name), name);
    assert.equal(events[0].args.id, id);
    assert.equal(events[0].args.addr, address);

    // badge count should increase
    const badgeCount = await badgeReg.badgeCount();
    assert.equal(badgeCount, 1);

    // the badge should be accessible through the getters
    let badge = await badgeReg.badge(id);
    assert.equal(badge[0], address);
    assert.equal(web3.toUtf8(badge[1]), name);
    assert.equal(badge[2], owner);

    badge = await badgeReg.fromAddress(address);
    assert.equal(badge[0], id);
    assert.equal(web3.toUtf8(badge[1]), name);
    assert.equal(badge[2], owner);

    badge = await badgeReg.fromName(name);
    assert.equal(badge[0], id);
    assert.equal(badge[1], address);
    assert.equal(badge[2], owner);
  });

  it("should allow the badge owner to set a new address for the badge", async () => {
    const badgeReg = await BadgeReg.deployed();
    const id = 0;
    const newAddress = accounts[1];

    const watcher = badgeReg.AddressChanged();

    // accounts[1] is not the badge owner so the request should fail
    await assertThrowsAsync(
      () => badgeReg.setAddress(id, newAddress, { from: accounts[1] }),
      "revert",
    );

    // sending request from badge owner account should succeed
    await badgeReg.setAddress(id, newAddress, { from: owner });

    // if successful the contract should emit a `AddressChanged` event
    const events = await watcher.get();

    assert.equal(events.length, 1);
    assert.equal(events[0].args.id, id);
    assert.equal(events[0].args.addr, newAddress);

    // badge should be accessible through getter with the new address
    const badge = await badgeReg.fromAddress(newAddress);
    assert.equal(badge[0], id);
    assert.equal(web3.toUtf8(badge[1]), name);
    assert.equal(badge[2], owner);

    // badge should no longer be accessible through old address
    await assertThrowsAsync(
      () => badgeReg.fromAddress(address),
      "invalid opcode",
    );

    // new address is the current badge address so the request should fail since the address is
    // already taken
    await assertThrowsAsync(
      () => badgeReg.setAddress(id, newAddress, { from: owner }),
      "revert",
    );

    // revert to original badge address
    await badgeReg.setAddress(id, address, { from: owner });
  });

  it("should allow the badge owner to associate metadata with a badge", async () => {
    const badgeReg = await BadgeReg.deployed();
    const id = 0;

    const watcher = badgeReg.MetaChanged();

    // accounts[1] is not the badge owner so the request should fail
    await assertThrowsAsync(
      () => badgeReg.setMeta(id, "key", "value", { from: accounts[1] }),
      "revert",
    );

    // sending request from badge owner account should succeed
    await badgeReg.setMeta(id, "key", "value", { from: owner });

    // if successful the contract should emit a `MetaChanged` event
    const events = await watcher.get();

    assert.equal(events.length, 1);
    assert.equal(events[0].args.id, id);
    assert.equal(web3.toUtf8(events[0].args.key), "key");
    assert.equal(web3.toUtf8(events[0].args.value), "value");

    // the badge metadata should be accessible through the getter
    const value = await badgeReg.meta(id, "key");
    assert.equal(web3.toUtf8(value), "value");
  });

  it("should abort registration if name or address is already registered", async () => {
    const badgeReg = await BadgeReg.deployed();

    const watcher = badgeReg.Registered();

    // name and address are already taken
    await assertThrowsAsync(
      () => badgeReg.register(address, name, { value: web3.toWei("1", "ether") }),
      "revert",
    );

    // name is already taken
    await assertThrowsAsync(
      () => badgeReg.register(accounts[1], name, { value: web3.toWei("1", "ether") }),
      "revert",
    );

    // address is already taken
    await assertThrowsAsync(
      () => badgeReg.register(address, "new_awesome", { value: web3.toWei("1", "ether") }),
      "revert",
    );

    // no events are emitted
    const events = await watcher.get();
    assert.equal(events.length, 0);
  });

  it("should abort registration if the fee isn't paid", async () => {
    const badgeReg = await BadgeReg.deployed();

    const watcher = badgeReg.Registered();

    // no value is sent with the transaction
    await assertThrowsAsync(
      () => badgeReg.register(accounts[1], "badger"),
      "revert",
    );

    // no sufficient value is sent with the transaction
    await assertThrowsAsync(
      () => badgeReg.register(accounts[1], "badger", { value: web3.toWei("0.5", "ether") }),
      "revert",
    );

    // no events are emitted
    const events = await watcher.get();
    assert.equal(events.length, 0);
  });

  it("should allow the owner of the contract to transfer ownership of the contract", async () => {
    const badgeReg = await BadgeReg.deployed();
    const watcher = badgeReg.NewOwner();

    // only the owner of the contract can transfer ownership
    await assertThrowsAsync(
      () => badgeReg.setOwner(accounts[1], { from: accounts[1] }),
      "revert",
    );

    let owner = await badgeReg.owner();
    assert.equal(owner, accounts[0]);

    // we successfully transfer ownership of the contract
    await badgeReg.setOwner(accounts[1]);

    // the `owner` should point to the new owner
    owner = await badgeReg.owner();
    assert.equal(owner, accounts[1]);

    // it should emit a `NewOwner` event
    const events = await watcher.get();

    assert.equal(events.length, 1);
    assert.equal(events[0].args.old, accounts[0]);
    assert.equal(events[0].args.current, accounts[1]);

    // the old owner can no longer set a new owner
    await assertThrowsAsync(
      () => badgeReg.setOwner(accounts[0], { from: accounts[0] }),
      "revert",
    );
  });

  it("should allow the contract owner to set the registration fee", async () => {
    const badgeReg = await BadgeReg.deployed();

    // only the contract owner can set a new fee
    await assertThrowsAsync(
      () => badgeReg.setFee(10, { from: accounts[0] }),
      "revert",
    );

    await badgeReg.setFee(10, { from: accounts[1] });
    const fee = await badgeReg.fee();

    assert.equal(fee, 10);
  });

  it("should allow the contract owner to unregister badges", async () => {
    const badgeReg = await BadgeReg.deployed();
    const id = 0;

    const watcher = badgeReg.Unregistered();

    // only the contract owner can unregister badges
    await assertThrowsAsync(
      () => badgeReg.unregister(id, { from: accounts[0] }),
      "revert",
    );

    await badgeReg.unregister(id, { from: accounts[1] });

    // it should emit a `Unregistered` event
    const events = await watcher.get();

    assert.equal(events.length, 1);
    assert.equal(web3.toUtf8(events[0].args.name), name);
    assert.equal(events[0].args.id, id);

    // badge count should decrease
    const badgeCount = await badgeReg.badgeCount();

    assert.equal(badgeCount, 0);
  });

  it("should allow the contract owner to drain all the ether from the contract", async () => {
    const badgeReg = await BadgeReg.deployed();

    // only the contract owner can drain the contract
    await assertThrowsAsync(
      () => badgeReg.drain({ from: accounts[0] }),
      "revert",
    );

    const balance = web3.eth.getBalance(accounts[1]);
    await badgeReg.drain({ from: accounts[1] });

    const newBalance = web3.eth.getBalance(accounts[1]);
    const expectedBalance = balance.plus(web3.toBigNumber(web3.toWei("0.99", "ether")));

    // accounts[1]'s balance should have increased by at least 0.99 ETH (to account for gas costs)
    assert(newBalance.gte(expectedBalance));
  });

  it("should not allow interactions with unregistered badges", async () => {
    const badgeReg = await BadgeReg.deployed();
    const id = 0;

    await assertThrowsAsync(
      () => badgeReg.badge(id),
      "revert",
    );

    await assertThrowsAsync(
      () => badgeReg.fromAddress(address),
      "invalid opcode",
    );

    await assertThrowsAsync(
      () => badgeReg.fromName(name),
      "invalid opcode",
    );

    await assertThrowsAsync(
      () => badgeReg.meta(id, "key"),
      "revert",
    );
  });
});
