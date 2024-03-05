// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// forgefmt: disable-start
import {ISicbo} from "src/v0/interface/ISicbo.sol";
import {Currency} from "src/v0/libraries/LibCurrency.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ChainlinkConsumer} from "src/v0/utils/ChainlinkConsumer.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// forge fmt: disable-end

contract Sicbo is
  ISicbo,
  Ownable,
  Pausable,
  ReentrancyGuard,
  ChainlinkConsumer
{
  Currency token; // sicbo token

  bool public genesisLockOnce = false;
  bool public genesisStartOnce = false;

  uint256 public minBetAmount;
  uint256 public protocolFee;
  uint256 public treasuryAmount;

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
    uint256 treasuryFee_
  )
    Ownable(_msgSender())
    ChainlinkComsumer(subscriptionId_, _msgSender(), consumer_)
  {
    token = token_;
    intervalSeconds_ = intervalSeconds_;
    bufferSeconds = bufferSeconds_;
    minBetAmount = minBetAmount_;
    treasuryFee = treasuryFee_;
  }

  function betOdd(uint256 epoch_, uint256 amount_) external whenNotPaused nonReentrant {
    require(epoch == currentEpoch, "Bet is too early/late");
    require(_bettable(epoch_), "Round is not bettable");
    require(amount_ >= minBetAmount, "Bet amount must be greater than minBetAmount");
    require(ledger[epoch_][_msgSender()].amount == 0, "Can only bet once per round");

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

  function betEven(uint256 epoch_, uint256 amount_) external whenNotPaused nonReentrant {
    require(epoch == currentEpoch, "Bet is too early/late");
    require(_bettable(epoch_), "Round is not bettable");
    require(amount_ >= minBetAmount, "Bet amount must be greater than minBetAmount");
    require(ledger[epoch_][_msgSender()].amount == 0, "Can only bet once per round"); 

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
      require(block.timestamp > rounds[epochs_[i]].closeTimestamp, "Round has not ended");

      uint256 addedReward = 0;

      if (rounds[epochs_[i]].oracleCalled) {
        require(claimable(epochs_[i], _msgSender()), "Not eligible for claim");
        Round memory round = rounds[epochs_[i]];
        addedReward = (ledger[epochs_[i]][_msgSender()].amount * round.rewardAmount) / round.rewardBaseCalAmount;
      } else {
        require(refundable(epochs_[i], _msgSender()), "Not eligible for refund");
        addedReward = ledger[epochs_[i]][_msgSender()].amount;
      }

      ledger[epochs_[i]][_msgSender()].claimed = true;
      reward += addedReward;

      emit Claimed(_msgSender(), epochs_[i], addedReward);
    }

    if (reward > 0) {
      token.transfer(_msgSender(), reward);
    }
  }

  function getRandomNumber() external onlyOwner {
    _requestRandomWords();
  }

  function executeRound() external whenNotPaused onlyOwner {
    require(
      genesisStartOnce && genesisLockOnce,
      "Can only run after genesisStartRound and genesisLockRound is triggered"
    );

    (bool isFulfilled, uint256[] memory randomWords) = getRequestStatus(lastRequestId);
    require(isFulfilled, "Can only run after request fulfilled");

    uint256 result = randomWords[0] % 2 + 1;
    
    _safeLockRound(currentEpoch);
    _safeEndRound(currentEpoch - 1, result);
    _calculateReward(currentEpoch -1);

    currentEpoch = currentEpoch + 1;
    _safeStartRound(currentEpoch);
  }

  function genesisLockRound() external whenNotPaused onlyOwner {
    require(genesisStartOnce, "Can only run after genesisStartRound is triggered");
    require(!genesisLockOnce, "Can only run genesisLockRound once");

    _safeLockRound(currentEpoch);

    currentEpoch = currentEpoch + 1;
    _startRound(currentEpoch);
    genesisLockOnce = true;
  }

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
    genesisLockOnce = false;
    _unpause();

    emit Unpause(currentEpoch);
  }

  function claimable(uint256 epoch_, address user_) public view returns (bool) {
    BetInfo memory betInfo = ledger[epoch_][user_];
    Round memory round = rounds[epoch_];
    return 
      round.oracleCalled &&
      betInfo.amount != 0 &&
      !betInfo.claimed &&
      (
        betInfo.position == Position.Odd ||
        betInfo.position == Position.Even
      );
  }

  function refundable(uint256 epoch_, address user_) public view returns (bool) {
    BetInfo memory betInfo = ledger[epoch_][user_];
    Round memory round = rounds[epoch_];
    return
      !round.oracleCalled &&
      !betInfo.claimed &&
      block.timestamp > round.closeTimestamp + bufferSeconds &&
      betInfo.amount != 0;
  }

  function _calculateRewards(uint256 epoch_) internal {

  }

  function _safeEndRound(uint256 epoch_, uint256 result_) internal {}

  function _safeLockRound(uint256 epoch_) internal {}

  function _safeStartRound(uint256 epoch_) internal {}

  function _startRound(uint256 epoch_) internal {}

  function _bettable(uint256 epoch_) internal view returns (bool) {
    return 
      rounds[epoch_].startTimestamp != 0 &&
      rounds[epoch_].lockTimestamp != 0 &&
      block.timestamp > rounds[epoch_].startTimestamp &&
      block.timestamp < rounds[epoch_].lockTimestamp;
  }
}
