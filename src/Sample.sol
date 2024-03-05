// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Sample {
  string public greeting;

  constructor() {
    greeting = "Hello world!";
  }
}

contract SampleUUPS is Initializable, UUPSUpgradeable {
  string public greeting;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize() public initializer {
    __UUPSUpgradeable_init();
    greeting = "Hello world!";
  }

  function _authorizeUpgrade(address) internal override {}
}

contract SampleTransparent is Initializable {
  string public greeting;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize() public initializer {
    greeting = "Hello world!";
  }
}
