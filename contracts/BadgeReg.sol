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

pragma solidity ^0.4.22;

import "./Owned.sol";


contract BadgeReg is Owned {
	struct Badge {
		address addr;
		bytes32 name;
		address owner;
		bool deleted;
		mapping (bytes32 => bytes32) meta;
	}

	event Registered(bytes32 indexed name, uint indexed id, address addr);
	event Unregistered(bytes32 indexed name, uint indexed id);
	event MetaChanged(uint indexed id, bytes32 indexed key, bytes32 value);
	event AddressChanged(uint indexed id, address addr);

	mapping (address => uint) mapFromAddress;
	mapping (bytes32 => uint) mapFromName;
	Badge[] badges;
	uint public badgeCount = 0;
	uint public fee = 1 ether;

	modifier whenFeePaid {
		require(msg.value >= fee);
		_;
	}

	modifier whenAddressFree(address _addr) {
		require(mapFromAddress[_addr] == 0);
		_;
	}

	modifier whenNameFree(bytes32 _name) {
		require(mapFromName[_name] == 0);
		_;
	}

	modifier whenBadge(uint _id) {
		require(!badges[_id].deleted);
		_;
	}

	modifier onlyBadgeOwner(uint _id) {
		require(badges[_id].owner == msg.sender);
		_;
	}

	function register(address _addr, bytes32 _name)
		external
		payable
		returns (bool)
	{
		return registerAs(_addr, _name, msg.sender);
	}

	function unregister(uint _id)
		external
		onlyOwner
		whenBadge(_id)
	{
		emit Unregistered(badges[_id].name, _id);
		delete mapFromAddress[badges[_id].addr];
		delete mapFromName[badges[_id].name];
		badges[_id].deleted = true;
		badgeCount = badgeCount - 1;
	}

	function setFee(uint _fee)
		external
		onlyOwner
	{
		fee = _fee;
	}

	function setAddress(uint _id, address _newAddr)
		external
		whenBadge(_id)
		onlyBadgeOwner(_id)
		whenAddressFree(_newAddr)
	{
		address oldAddr = badges[_id].addr;
		badges[_id].addr = _newAddr;
		mapFromAddress[oldAddr] = 0;
		mapFromAddress[_newAddr] = _id + 1;
		emit AddressChanged(_id, _newAddr);
	}

	function setMeta(uint _id, bytes32 _key, bytes32 _value)
		external
		whenBadge(_id)
		onlyBadgeOwner(_id)
	{
		badges[_id].meta[_key] = _value;
		emit MetaChanged(_id, _key, _value);
	}

	function drain()
		external
		onlyOwner
	{
		msg.sender.transfer(address(this).balance);
	}

	function badge(uint _id)
		external
		view
		whenBadge(_id)
		returns (address addr, bytes32 name, address owner)
	{
		Badge storage t = badges[_id];
		addr = t.addr;
		name = t.name;
		owner = t.owner;
	}

	function fromAddress(address _addr)
		external
		view
		returns (uint id, bytes32 name, address owner)
	{
		id = mapFromAddress[_addr];
		require(id > 0);
		id = id - 1;
		Badge storage b = badges[id];
		name = b.name;
		owner = b.owner;
	}

	function fromName(bytes32 _name)
		external
		view
		returns (uint id, address addr, address owner)
	{
		id = mapFromName[_name];
		require(id > 0);
		id = id - 1;
		Badge storage b = badges[id];
		addr = b.addr;
		owner = b.owner;
	}

	function meta(uint _id, bytes32 _key)
		external
		view
		whenBadge(_id)
		returns (bytes32)
	{
		return badges[_id].meta[_key];
	}

	function registerAs(address _addr, bytes32 _name, address _owner)
		public
		payable
		whenFeePaid
		whenAddressFree(_addr)
		whenNameFree(_name)
		returns (bool)
	{
		badges.push(Badge({
			addr: _addr,
			name: _name,
			owner: _owner,
			deleted: false
		}));
		mapFromAddress[_addr] = badges.length;
		mapFromName[_name] = badges.length;
		badgeCount = badgeCount + 1;
		emit Registered(_name, badges.length - 1, _addr);
		return true;
	}
}
