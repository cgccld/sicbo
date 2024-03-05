// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./Migrate.s.sol";
import {SIBO} from "src/v0/SIBO.sol";
import {Sicbo} from "src/v0/Sicbo.sol";

contract SicboDeployer is BaseMigrate {
  function run() public {
    deploySicbo();
  }

  function deploySicbo() public broadcast {
    address sibo = deployContract("SIBO.sol:SIBO", abi.encode());
    deployContract(
      "Sicbo.sol:Sicbo", 
      abi.encode(
        sibo,
        1470,
        0x2eD832Ba664535e5886b75D64C46EB9a228C2610,
        300,
        30,
        1000000000000000000,
        300
      )
    );
  }
}