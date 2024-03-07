// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// forgefmt: disable-start
import {ISicbo} from "src/v0/interface/ISicbo.sol";
import {Currency} from "src/v0/libraries/LibCurrency.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ChainlinkConsumer} from "src/v0/utils/ChainlinkConsumer.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// forgefmt: disable-end

contract Sicbo is ISicbo, Pausable, ReentrancyGuard, ChainlinkConsumer {
  Currency token; // sicbo token

  // bool public genesisLockOnce = false;
  bool public genesisStartOnce = false;

  uint256 public minBetAmount;
  uint256 public protocolFee;
  uint256 public treasuryAmount;
  uint256 public bufferSeconds;
  uint256 public intervalSeconds;
  uint256 public currentEpoch;

  mapping(uint256 => mapping(address => BetInfo)) public ledger;
  mapping(uint256 => Round) public rounds;
  mapping(address => uint256[]) public userRounds;

  constructor(
    Currency token_,
    uint64 subscriptionId_,
    address consumer_,
    uint256 intervalSeconds_,
    uint256 bufferSeconds_,
    uint256 minBetAmount_,
    uint256 protocolFee_
  ) ChainlinkConsumer(subscriptionId_, _msgSender(), consumer_) {
    token = token_;
    intervalSeconds = intervalSeconds_;
    bufferSeconds = bufferSeconds_;
    minBetAmount = minBetAmount_;
    protocolFee = protocolFee_;
  }

  function betOdd(uint256 epoch_, uint256 amount_)
    external
    whenNotPaused
    nonReentrant
  {
    require(epoch_ == currentEpoch, "Bet is too early/late");
    require(_bettable(epoch_), "Round is not bettable");
    require(
      amount_ >= minBetAmount, "Bet amount must be greater than minBetAmount"
    );
    require(
      ledger[epoch_][_msgSender()].amount == 0, "Can only bet once per round"
    );

    token.receiveFrom(_msgSender(), amount_);
    // Update round data
    uint256 amount = amount_;
    Round storage round = rounds[epoch_];
    round.totalAmount += amount;
    round.oddAmount += amount;

    // Update user data
    BetInfo storage betInfo = ledger[epoch_][_msgSender()];
    betInfo.position = Position.Odd;
    betInfo.amount = amount;
    userRounds[_msgSender()].push(epoch_);

    emit BetOdd(_msgSender(), epoch_, amount);
  }

  function betEven(uint256 epoch_, uint256 amount_)
    external
    whenNotPaused
    nonReentrant
  {
    require(epoch_ == currentEpoch, "Bet is too early/late");
    require(_bettable(epoch_), "Round is not bettable");
    require(
      amount_ >= minBetAmount, "Bet amount must be greater than minBetAmount"
    );
    require(
      ledger[epoch_][_msgSender()].amount == 0, "Can only bet once per round"
    );

    token.receiveFrom(_msgSender(), amount_);
    // Update round data
    uint256 amount = amount_;
    Round storage round = rounds[epoch_];
    round.totalAmount += amount;
    round.evenAmount += amount;

    // Update user data
    BetInfo storage betInfo = ledger[epoch_][_msgSender()];
    betInfo.position = Position.Even;
    betInfo.amount = amount;
    userRounds[_msgSender()].push(epoch_);

    emit BetEven(_msgSender(), epoch_, amount);
  }

  function claim(uint256[] calldata epochs_) external nonReentrant {
    uint256 reward;

    for (uint256 i; i < epochs_.length; ++i) {
      require(rounds[epochs_[i]].startTimestamp != 0, "Round has not started");
      require(
        block.timestamp > rounds[epochs_[i]].closeTimestamp,
        "Round has not ended"
      );

      uint256 addedReward = 0;

      if (rounds[epochs_[i]].requestedRandom) {
        require(claimable(epochs_[i], _msgSender()), "Not eligible for claim");
        Round memory round = rounds[epochs_[i]];
        addedReward = (
          ledger[epochs_[i]][_msgSender()].amount * round.rewardAmount
        ) / round.rewardBaseCalAmount;
      } else {
        require(refundable(epochs_[i], _msgSender()), "Not eligible for refund");
        addedReward = ledger[epochs_[i]][_msgSender()].amount;
      }

      ledger[epochs_[i]][_msgSender()].claimed = true;
      reward += addedReward;

      emit Claim(_msgSender(), epochs_[i], addedReward);
    }

    if (reward > 0) {
      token.transfer(_msgSender(), reward);
    }
  }

  function resolveRound() external whenNotPaused onlyOwner {
    _requestRandomWords();
    // _safeLockRound(currentEpoch);
  }

  function executeRound() external whenNotPaused onlyOwner {
    require(
      genesisStartOnce,
      "Can only run after genesisStartRound is triggered"
    );

    (bool isFulfilled, uint256[] memory randomWords) =
      getRequestStatus(lastRequestId);
    require(isFulfilled, "Can only run after request fulfilled");

    uint256 result = randomWords[0] % 2 + 1;

    _safeEndRound(currentEpoch, lastRequestId, result);
    _calculateRewards(currentEpoch);

    currentEpoch = currentEpoch + 1;
    _safeStartRound(currentEpoch);
  }

  // function genesisLockRound() external whenNotPaused onlyOwner {
  //   require(
  //     genesisStartOnce, "Can only run after genesisStartRound is triggered"
  //   );
  //   require(!genesisLockOnce, "Can only run genesisLockRound once");

  //   _safeLockRound(currentEpoch);

  //   currentEpoch = currentEpoch + 1;
  //   _startRound(currentEpoch);
  //   genesisLockOnce = true;
  // }

  function genesisStartRound() external whenNotPaused onlyOwner {
    require(!genesisStartOnce, "Can only run genesisStartRound once");

    currentEpoch = currentEpoch + 1;
    _startRound(currentEpoch);
    genesisStartOnce = true;
  }

  function pause() external whenNotPaused onlyOwner {
    _pause();

    emit Pause(currentEpoch);
  }

  function unpause() external whenPaused onlyOwner {
    genesisStartOnce = false;
    // genesisLockOnce = false;
    _unpause();

    emit Unpause(currentEpoch);
  }

  function setBufferAndIntervalSeconds(
    uint256 bufferSeconds_,
    uint256 intervalSeconds_
  ) external whenPaused onlyOwner {
    require(
      bufferSeconds_ < intervalSeconds_,
      "bufferSeconds must be inferior to intervalSeconds"
    );

    bufferSeconds = bufferSeconds_;
    intervalSeconds = intervalSeconds_;

    emit NewBufferAndIntervalSeconds(bufferSeconds_, intervalSeconds_);
  }

  function setMinBetAmount(uint256 minBetAmount_) external whenPaused onlyOwner {
    require(minBetAmount_ != 0, "Must be superior to 0");

    minBetAmount = minBetAmount_;

    emit NewMinBetAmount(currentEpoch, minBetAmount);
  }

  function setProtocolFee(uint256 protocolFee_) external whenPaused onlyOwner {
    protocolFee = protocolFee_;

    emit NewProtocolFee(currentEpoch, protocolFee_);
  }

  function getUserRounds(address user, uint256 cursor, uint256 size)
    external
    view
    returns (uint256[] memory, BetInfo[] memory, uint256)
  {
    uint256 length = size;

    if (length > userRounds[user].length - cursor) {
      length = userRounds[user].length - cursor;
    }

    uint256[] memory values = new uint256[](length);
    BetInfo[] memory betInfo = new BetInfo[](length);

    for (uint256 i = 0; i < length; i++) {
      values[i] = userRounds[user][cursor + i];
      betInfo[i] = ledger[values[i]][user];
    }

    return (values, betInfo, cursor + length);
  }

  function getUserRoundsLength(address user) external view returns (uint256) {
    return userRounds[user].length;
  }

  function claimable(uint256 epoch_, address user_) public view returns (bool) {
    BetInfo memory betInfo = ledger[epoch_][user_];
    Round memory round = rounds[epoch_];
    return round.requestedRandom && betInfo.amount != 0 && !betInfo.claimed
      && (betInfo.position == Position.Odd || betInfo.position == Position.Even);
  }

  function refundable(uint256 epoch_, address user_) public view returns (bool) {
    BetInfo memory betInfo = ledger[epoch_][user_];
    Round memory round = rounds[epoch_];
    return !round.requestedRandom && !betInfo.claimed
      && block.timestamp > round.closeTimestamp + bufferSeconds
      && betInfo.amount != 0;
  }

  function recoverToken(Currency token_, uint256 amount_) external onlyOwner {
    require(!(token_ == token), "Cannot recover sicbo token");
    token_.transfer(_msgSender(), amount_);

    emit TokenRecovery(Currency.unwrap(token_), amount_);
  }

  function _calculateRewards(uint256 epoch_) internal {
    require(
      rounds[epoch_].rewardBaseCalAmount == 0
        && rounds[epoch_].rewardAmount == 0,
      "Rewards calculated"
    );
    Round storage round = rounds[epoch_];
    uint256 rewardBaseCalAmount;
    uint256 treasuryAmt;
    uint256 rewardAmount;

    if (round.closeResult % 2 == 0) {
      rewardBaseCalAmount = round.evenAmount;
      treasuryAmt = (round.totalAmount * protocolFee) / 10_000;
      rewardAmount = round.totalAmount - treasuryAmt;
    } else if (round.closeResult % 2 == 1) {
      rewardBaseCalAmount = round.oddAmount;
      treasuryAmt = (round.totalAmount * protocolFee) / 10_000;
      rewardAmount = round.totalAmount - treasuryAmt;
    } else {
      rewardBaseCalAmount = 0;
      rewardAmount = 0;
      treasuryAmt = round.totalAmount;
    }
    round.rewardBaseCalAmount = rewardBaseCalAmount;
    round.rewardAmount = rewardAmount;

    treasuryAmount += treasuryAmt;

    emit RewardsCalculated(
      epoch_, rewardBaseCalAmount, rewardAmount, treasuryAmt
    );
  }

  function _safeEndRound(uint256 epoch_, uint256 requestId_, uint256 result_)
    internal
  {
    require(
      rounds[epoch_].lockTimestamp != 0,
      "Can only end round after round has locked"
    );
    require(
      block.timestamp >= rounds[epoch_].closeTimestamp,
      "Can only end round after closeTimestamp"
    );
    require(
      block.timestamp <= rounds[epoch_].closeTimestamp + bufferSeconds,
      "Can only end round within bufferSeconds"
    );

    Round storage round = rounds[epoch_];
    round.closeResult = result_;
    round.closeRequestId = requestId_;
    round.requestedRandom = true;

    emit EndRound(epoch_, requestId_, result_);
  }

  // function _safeLockRound(uint256 epoch_) internal {
  //   require(
  //     rounds[epoch_].startTimestamp != 0,
  //     "Can only lock round after round has started"
  //   );
  //   require(
  //     block.timestamp >= rounds[epoch_].lockTimestamp,
  //     "Can only lock round after lockTimestamp"
  //   );
  //   require(
  //     block.timestamp <= rounds[epoch_].lockTimestamp + bufferSeconds,
  //     "Can only lock round within bufferSeconds"
  //   );
  //   Round storage round = rounds[epoch_];
  //   round.closeTimestamp = block.timestamp + intervalSeconds;

  //   emit LockRound(epoch_);
  // }

  function _safeStartRound(uint256 epoch_) internal {
    require(
      genesisStartOnce, "Can only run after genesisStartRound is triggered"
    );
    require(
      rounds[epoch_ - 1].closeTimestamp != 0,
      "Can only start round after round n-1 has ended"
    );
    require(
      block.timestamp >= rounds[epoch_ - 1].closeTimestamp,
      "Can only start new round after round n-1 closeTimestamp"
    );
    _startRound(epoch_);
  }

  function _startRound(uint256 epoch_) internal {
    Round storage round = rounds[epoch_];
    round.startTimestamp = block.timestamp;
    round.lockTimestamp = block.timestamp + intervalSeconds;
    round.closeTimestamp = block.timestamp + (2 * intervalSeconds);
    round.epoch = epoch_;
    round.totalAmount = 0;

    emit StartRound(epoch_);
  }

  function _bettable(uint256 epoch_) internal view returns (bool) {
    return rounds[epoch_].startTimestamp != 0
      && rounds[epoch_].lockTimestamp != 0
      && block.timestamp > rounds[epoch_].startTimestamp
      && block.timestamp < rounds[epoch_].lockTimestamp;
  }
}
