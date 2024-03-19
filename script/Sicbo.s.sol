// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./Migrate.s.sol";
import {SicBo} from "../src/SicBo.sol";
import {Pampda} from "../src/Pampda.sol";

contract SicboDeployer is BaseMigrate {
  function run() public {
    deploy();
  }

  function deploy() public broadcast {
    address sibo = deployContract("Pampda.sol:Pampda", abi.encode("Pampda","$PAMP"));
    deployContract(
      "Sicbo.sol:Sicbo",
      abi.encode(
        sibo, 
        0x5498BB86BC934c8D34FDA08E81D444153d0D06aD,
        msg.sender,
        msg.sender,
        180,
        60, 
        1 ether, 
        120, // 120 seconds
        300 // 0.3 %
      )
    );
  }
}
