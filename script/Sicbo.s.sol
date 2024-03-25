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
    // address sibo = deployContract("Pampda.sol:Pampda", abi.encode("Pampda","$PAMP"));
    address sicbo = 0x116c3e2C25E3BC99F36e130cf267c372B82c3d36;
    deployContract(
      "Sicbo.sol:Sicbo",
      abi.encode(
        sicbo, 
        0x5498BB86BC934c8D34FDA08E81D444153d0D06aD,
        msg.sender,
        0xeeC5915A21DA64a58DE1e9a3D7dd7b8Bff775cF0,
        180,
        180, 
        1 ether, 
        120, // 120 seconds
        300 // 0.3 %
      )
    );
  }
}
