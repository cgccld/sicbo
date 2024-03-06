// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./Migrate.s.sol";
import {SIBO} from "src/v0/SIBO.sol";
import {Sicbo} from "src/v0/Sicbo.sol";

contract SicboDeployer is BaseMigrate {
  function run() public {
    deploySicbo();

    // Sicbo(payable(0x0f81c587aC9a3116b2a320Cdfd1cA06c1EA7bB12)).getRandomNumber();
  }

  function deploySicbo() public broadcast {
    address sibo = deployContract("SIBO.sol:SIBO", abi.encode());
    address sicbo = deployContract(
      "Sicbo.sol:Sicbo",
      abi.encode(
        sibo,
        1470,
        0x2eD832Ba664535e5886b75D64C46EB9a228C2610,
        300,
        30,
        1_000_000_000_000_000_000,
        300
      )
    );

    Sicbo(payable(sicbo)).requestRandomWords();
    vm.warp(block.timestamp + 400);
    Sicbo(payable(sicbo)).getRequestStatus(
      Sicbo(payable(sicbo)).lastRequestId()
    );
  }
}
