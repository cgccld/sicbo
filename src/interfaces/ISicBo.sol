// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ISicBo {
  enum Position {
    Low,
    High
  }

  struct BetInfo {
    Position position;
    uint256 amount;
    bool claimed;
  }

  struct DiceResult {
    uint256 rollAt;
    uint256 totalScore;
    uint256[] dices;
  }

  struct Round {
    uint256 epoch;
    uint256 startAt;
    uint256 closeAt;
    uint256 roundId;
    uint256 totalAmount;
    uint256 lowAmount;
    uint256 numBetLow;
    uint256 highAmount;
    uint256 numBetHigh;
    uint256 rewardBaseCalAmount;
    uint256 rewardAmount;
    bool requestedPriceFeed;
    DiceResult diceResult;
  }

  event BetLow(address indexed account, uint256 indexed epoch, uint256 amount);
  event BetHigh(address indexed account, uint256 indexed epoch, uint256 amount);
  event Claim(address indexed account, uint256 indexed epoch, uint256 amount);

  event StartRound(uint256 indexed epoch);
  event EndRound(uint256 indexed epoch, uint256 indexed roundId, uint256 totalScore);

  event Pause(uint256 indexed epoch);
  event Unpause(uint256 indexed epoch);

  event RewardsCalculated(
    uint256 indexed epoch, uint256 rewardBaseCalAmount, uint256 rewardAmount, uint256 treasuryAmount
  );

  event TreasuryClaim(uint256 amount);
  event TokenRecovery(address indexed token, uint256 amount);
  
  event NewOracle(address oracle);
  event NewOracleUpdateAllowance(uint256 oracleUpdateAllowance);
  event NewTreasuryFee(uint256 indexed epoch, uint256 treasuryFee);
  event NewMinBetAmount(uint256 indexed epoch, uint256 minBetAmount);
  event NewBufferAndIntervalSeconds(uint256 bufferSeconds, uint256 intervalSeconds);
}
