pragma solidity ^0.4.21;

import "truffle/Assert.sol";
import "../contracts/BadgeReg.sol";


contract TestBadgeReg {
	function testRegisterUnregister() public {
		BadgeReg reg = new BadgeReg();
		reg.setFee(0);

		reg.register(0x1, "hello");
		uint id;
		(id,,) = reg.fromAddress(0x1);
		reg.unregister(id);
	}
}
