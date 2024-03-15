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

  struct Round {
    bool requestedQRNG;
    uint256 epoch;
    uint256 startAt;
    uint256 closeAt;
    uint256 totalAmount;
    uint256 lowAmount;
    uint256 highAmount;
    uint256 rewardBaseCalAmount;
    uint256 rewardAmount;
    bytes32 requestId;
    uint256 closeTotalScore;
    uint256[] closeDicesResult;
  }

  struct SicBoSettings {
    uint256 treasuryFee;
    uint256 minBetAmount;
    uint256 bufferSeconds;
    uint256 intervalSeconds;
  }

  event BetLow(address indexed account, uint256 indexed epoch, uint256 amount);
  event BetHigh(address indexed account, uint256 indexed epoch, uint256 amount);
  event Claim(address indexed account, uint256 indexed epoch, uint256 amount);

  event SettingsConfigured(address indexed by);

  event StartRound(uint256 indexed epoch);
  event EndRound(uint256 indexed epoch, bytes32 indexed requestId, uint256 totalScore);

  event Pause(uint256 indexed epoch);
  event Unpause(uint256 indexed epoch);

  event RewardsCalculated(
    uint256 indexed epoch, uint256 rewardBaseCalAmount, uint256 rewardAmount, uint256 treasuryAmount
  );

  event TreasuryClaim(uint256 amount);
  event TokenRecovery(address indexed token, uint256 amount);
}
