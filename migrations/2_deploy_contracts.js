"use strict";

const BadgeReg = artifacts.require("./BadgeReg.sol");

module.exports = deployer => {
  deployer.deploy(BadgeReg);
};
