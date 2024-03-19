// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./Migrate.s.sol";
import {SicBo} from "src/SicBo.sol";

contract SicboDeployer is BaseMigrate {
  function run() public {
    deploySicbo();
  }

  function deploySicbo() public broadcast {
    address sibo = 0x2F08eC295cF70fD1D4985cEC1cDf756d8495a1de;
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
