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
    address sibo = 0x2F08eC295cF70fD1D4985cEC1cDf756d8495a1de;
    address sicbo = deployContract(
      "Sicbo.sol:Sicbo",
      abi.encode(
        sibo,
        1470,
        0x2eD832Ba664535e5886b75D64C46EB9a228C2610,
        60,
        300,
        1_000_000_000_000_000_000,
        300
      )
    );
  }
}
