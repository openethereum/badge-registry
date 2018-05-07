//! The badge-registry contract.
//!
//! Copyright 2016 Gavin Wood, Parity Technologies Ltd.
//!
//! Licensed under the Apache License, Version 2.0 (the "License");
//! you may not use this file except in compliance with the License.
//! You may obtain a copy of the License at
//!
//!     http://www.apache.org/licenses/LICENSE-2.0
//!
//! Unless required by applicable law or agreed to in writing, software
//! distributed under the License is distributed on an "AS IS" BASIS,
//! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//! See the License for the specific language governing permissions and
//! limitations under the License.

pragma solidity ^0.4.17;

import "Owned.sol";


contract BadgeReg is Owned {
	struct Badge {
		address addr;
		bytes32 name;
		address owner;
		mapping (bytes32 => bytes32) meta;
	}

	modifier whenFeePaid {
		if (msg.value < fee)
			return;
		_;
	}
	modifier whenAddressFree(address _addr) {
		if (mapFromAddress[_addr] != 0)
			return;
		_;
	}
	modifier whenNameFree(bytes32 _name) {
		if (mapFromName[_name] != 0)
			return;
		_;
	}
	modifier whenHasName(bytes32 _name) {
		if (mapFromName[_name] == 0)
			return;
		_;
	}
	modifier onlyBadgeOwner(uint _id) {
		if (badges[_id].owner != msg.sender)
			return;
		_;
	}

	event Registered(bytes32 indexed name, uint indexed id, address addr);
	event Unregistered(bytes32 indexed name, uint indexed id);
	event MetaChanged(uint indexed id, bytes32 indexed key, bytes32 value);
	event AddressChanged(uint indexed id, address addr);

	function register(address _addr, bytes32 _name) payable public returns (bool) {
		return registerAs(_addr, _name, msg.sender);
	}

	function registerAs(address _addr, bytes32 _name, address _owner)
		payable whenFeePaid whenAddressFree(_addr) whenNameFree(_name)
		public returns (bool)
	{
		badges.push(Badge(_addr, _name, _owner));
		mapFromAddress[_addr] = badges.length;
		mapFromName[_name] = badges.length;
		emit Registered(_name, badges.length - 1, _addr);
		return true;
	}

	function unregister(uint _id) onlyOwner public {
		emit Unregistered(badges[_id].name, _id);
		delete mapFromAddress[badges[_id].addr];
		delete mapFromName[badges[_id].name];
		delete badges[_id];
	}

	function setFee(uint _fee) onlyOwner public {
		fee = _fee;
	}

	function badgeCount() view public returns (uint) { return badges.length; }

	function badge(uint _id) view public returns (address addr, bytes32 name, address owner) {
		var t = badges[_id];
		addr = t.addr;
		name = t.name;
		owner = t.owner;
	}

	function fromAddress(address _addr) view public returns (uint id, bytes32 name, address owner) {
		id = mapFromAddress[_addr] - 1;
		var t = badges[id];
		name = t.name;
		owner = t.owner;
	}

	function fromName(bytes32 _name) view public returns (uint id, address addr, address owner) {
		id = mapFromName[_name] - 1;
		var t = badges[id];
		addr = t.addr;
		owner = t.owner;
	}

	function meta(uint _id, bytes32 _key) view public returns (bytes32) {
		return badges[_id].meta[_key];
	}

	function setAddress(uint _id, address _newAddr) onlyBadgeOwner(_id) whenAddressFree(_newAddr) public {
		var oldAddr = badges[_id].addr;
		badges[_id].addr = _newAddr;
		mapFromAddress[oldAddr] = 0;
		mapFromAddress[_newAddr] = _id;
		emit AddressChanged(_id, _newAddr);
	}

	function setMeta(uint _id, bytes32 _key, bytes32 _value) onlyBadgeOwner(_id) public {
		badges[_id].meta[_key] = _value;
		emit MetaChanged(_id, _key, _value);
	}

	function drain() only_owner public {
		msg.sender.transfer(this.balance);
	}

	mapping (address => uint) mapFromAddress;
	mapping (bytes32 => uint) mapFromName;
	Badge[] badges;
	uint public fee = 1 ether;
}
