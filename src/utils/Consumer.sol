// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

abstract contract Consumer {
  AggregatorV3Interface internal dataFeed;

  constructor(address aggregator) {
    dataFeed = AggregatorV3Interface(aggregator);
  }

  function getLatestAnswer() public view returns (uint256, uint256) {
    (
      uint80 roundID,
      int256 answer,
      /*uint startedAt*/
      ,
      /*uint256 timeStamp*/
      ,
      /*uint80 answeredInRound*/
    ) = dataFeed.latestRoundData();

    return (uint256(roundID), uint256(answer));
  }
}
