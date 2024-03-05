// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./Migrate.s.sol";
import {Sample, SampleUUPS, SampleTransparent} from "src/Sample.sol";

contract SampleDeploy is BaseMigrate {
  function run() external {
    deploySample();
    deploySampleUUPS();
    deploySampleTransparent();
    _postCheck();
  }

  function deploySample() public broadcast {
    deployContract("Sample.sol:Sample", abi.encode());
  }

  function deploySampleUUPS() public broadcast {
    deployUUPSProxy("Sample.sol:SampleUUPS", abi.encodeCall(SampleUUPS.initialize, ()));
  }

  function deploySampleTransparent() public broadcast {
    deployTransparentProxy("Sample.sol:SampleTransparent", abi.encodeCall(SampleUUPS.initialize, ()));
  }

  function _postCheck() internal pure override log("_postCheck") {}
}
