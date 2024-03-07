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
    // address userA = makeAddr("user-a");
    // address userB = makeAddr("user-b");
    // address owner = 0x203f00E1e4906BaB4BF4b3acBA3cB2cfB95F9C84;
    
    address sibo = 0x2F08eC295cF70fD1D4985cEC1cDf756d8495a1de;
    // vm.prank(owner, owner);
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

    // SIBO(payable(sibo)).mint(userA, 100 ether);
    // SIBO(payable(sibo)).mint(userB, 100 ether); 

    // vm.prank(userA, userA);
    // SIBO(payable(sibo)).approve(sicbo, 100 ether);
    // vm.prank(userB, userB);
    // SIBO(payable(sibo)).approve(sicbo, 100 ether);

    // vm.prank(owner, owner);
    // Sicbo(payable(sicbo)).genesisStartRound();

    // vm.warp(block.timestamp + 1800);
    // vm.prank(owner, owner);
    // Sicbo(payable(sicbo)).genesisLockRound();

    // vm.warp(block.timestamp + 1);
    // vm.prank(userA, userA);
    // Sicbo(payable(sicbo)).betOdd(2, 100 ether);
    // vm.prank(userB, userB);
    // Sicbo(payable(sicbo)).betEven(2, 100 ether); 
    
    // vm.warp(block.timestamp + 1801);
    // vm.prank(owner, owner);
    // Sicbo(payable(sicbo)).resolveRound();
    
    // vm.warp(block.timestamp + 290);
    // vm.prank(owner, owner);
    // Sicbo(payable(sicbo)).executeRound();
    // Sicbo(payable(sicbo)).getRequestStatus(
    //   Sicbo(payable(sicbo)).lastRequestId()
    // );
  }
}
