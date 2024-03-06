// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ISicbo {
  enum Position {
    Odd,
    Even
  }

  struct Round {
    uint256 epoch;
    uint256 startTimestamp;
    uint256 lockTimestamp;
    uint256 closeTimestamp;
    uint256 closeRequestId;
    uint256 closeResult;
    uint256 totalAmount;
    uint256 oddAmount;
    uint256 evenAmount;
    uint256 rewardBaseCalAmount;
    uint256 rewardAmount;
    bool oracleCalled;
  }

  struct BetInfo {
    Position position;
    uint256 amount;
    bool claimed;
  }

  event BetOdd(address indexed gambler, uint256 indexed epoch, uint256 amount);
  event BetEven(address indexed gambler, uint256 indexed epoch, uint256 amount);
  event Claim(address indexed gambler, uint256 indexed epoch, uint256 amount);

  event NewProtocolFee(uint256 indexed epoch, uint256 protocolFee);
  event NewMinBetAmount(uint256 indexed epoch, uint256 minBetAmount);
  event NewBufferAndIntervalSeconds(
    uint256 bufferSeconds, uint256 intervalSeconds
  );

  event StartRound(uint256 indexed epoch);
  event LockRound(uint256 indexed epoch);
  event EndRound(
    uint256 indexed epoch, uint256 indexed requestId, uint256 resultNumber
  );

  event Pause(uint256 indexed epoch);
  event Unpause(uint256 indexed epoch);

  event RewardsCalculated(
    uint256 indexed epoch,
    uint256 rewardBaseCalAmount,
    uint256 rewardAmount,
    uint256 treasuryAmount
  );

  event TreasuryClaim(uint256 amount);
  event TokenRecovery(address indexed token, uint256 amount);
}
