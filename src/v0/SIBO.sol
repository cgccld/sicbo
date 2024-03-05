// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SIBO is ERC20 {
  constructor() ERC20("Sicbo20", "SIBO") {}

  function mint(address to_, uint256 value_) external {
    _mint(to_, value_);
  }

  function burn(address from_, uint256 value_) external {
    _burn(from_, value_);
  }
}