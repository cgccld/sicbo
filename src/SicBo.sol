// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// forgefmt: disable-start
import {ISicBo} from "src/ISicBo.sol";
import {Currency} from "src/libraries/LibCurrency.sol";
import {IConsumer, Consumer} from "src/utils/Consumer.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// forgefmt: disable-end

contract SicBo is ISicBo, Pausable, ReentrancyGuard, Consumer, Ownable {
  Currency currency;

  bool public genesisStartOnce; // default false;
  uint256 public currentEpoch;
  uint256 public treasuryAmount;

  SicBoSettings public sbSettings;

  mapping(uint256 => Round) public rounds;
  mapping(address => uint256[]) public userRounds;
  mapping(uint256 => mapping(address => BetInfo)) public ledger;

  constructor(
    bytes32 keyHash_,
    Currency currency_,
    address coordinator_,
    uint256 treasuryFee_,
    uint256 minBetAmount_,
    uint64 subscriptionId_,
    uint256 bufferSeconds_,
    uint256 intervalSeconds_
  )
    Ownable(_msgSender())
    Consumer(
      IConsumer.ConsumerSettings({
        numWords: 3,
        numConfirms: 3,
        gasLimit: 100_000,
        keyHash: keyHash_,
        subsId: subscriptionId_,
        coordinator: coordinator_
      })
    )
  {
    currency = currency_;
    sbSettings = ISicBo.SicBoSettings({
      treasuryFee: treasuryFee_,
      minBetAmount: minBetAmount_,
      bufferSeconds: bufferSeconds_,
      intervalSeconds: intervalSeconds_
    });
  }

  // VIEWS
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
    return round.requestedVRF && betInfo.amount != 0 && !betInfo.claimed
      && (betInfo.position == Position.Low || betInfo.position == Position.High);
  }

  function refundable(uint256 epoch_, address user_) public view returns (bool) {
    uint256 bufferSeconds = sbSettings.bufferSeconds;
    BetInfo memory betInfo = ledger[epoch_][user_];
    Round memory round = rounds[epoch_];
    return
      !round.requestedVRF && !betInfo.claimed && block.timestamp > round.closeAt + bufferSeconds && betInfo.amount != 0;
  }

  // WRITE
  // 3 dices -> 4 -> 10
  function betLow(uint256 epoch_, uint256 amount_) external whenNotPaused nonReentrant {
    require(epoch_ == currentEpoch, "Bet is too early/late");
    require(_bettable(epoch_), "Round is not bettable");
    require(amount_ >= sbSettings.minBetAmount, "Bet amount must be greater than minBetAmount");
    require(ledger[epoch_][_msgSender()].amount == 0, "Can only bet once per round");

    currency.receiveFrom(_msgSender(), amount_);
    // Update round data
    uint256 amount = amount_;
    Round storage round = rounds[epoch_];
    round.totalAmount += amount;
    round.lowAmount += amount;

    // Update user data
    BetInfo storage betInfo = ledger[epoch_][_msgSender()];
    betInfo.position = Position.Low;
    betInfo.amount = amount;
    userRounds[_msgSender()].push(epoch_);

    emit BetLow(_msgSender(), epoch_, amount);
  }

  // 3 dices -> 11 -> 17
  function betHigh(uint256 epoch_, uint256 amount_) external whenNotPaused nonReentrant {
    require(epoch_ == currentEpoch, "Bet is too early/late");
    require(_bettable(epoch_), "Round is not bettable");
    require(amount_ >= sbSettings.minBetAmount, "Bet amount must be greater than minBetAmount");
    require(ledger[epoch_][_msgSender()].amount == 0, "Can only bet once per round");

    currency.receiveFrom(_msgSender(), amount_);
    // Update round data
    uint256 amount = amount_;
    Round storage round = rounds[epoch_];
    round.totalAmount += amount;
    round.highAmount += amount;

    // Update user data
    BetInfo storage betInfo = ledger[epoch_][_msgSender()];
    betInfo.position = Position.High;
    betInfo.amount = amount;
    userRounds[_msgSender()].push(epoch_);

    emit BetHigh(_msgSender(), epoch_, amount);
  }

  function claim(uint256[] calldata epochs_) external nonReentrant {
    uint256 reward;

    for (uint256 i; i < epochs_.length; ++i) {
      require(rounds[epochs_[i]].startAt != 0, "Round has not started");
      require(block.timestamp > rounds[epochs_[i]].closeAt, "Round has not ended");

      uint256 addedReward = 0;

      if (rounds[epochs_[i]].requestedVRF) {
        require(claimable(epochs_[i], _msgSender()), "Not eligible for claim");
        Round memory round = rounds[epochs_[i]];
        addedReward = (ledger[epochs_[i]][_msgSender()].amount * round.rewardAmount) / round.rewardBaseCalAmount;
      } else {
        require(refundable(epochs_[i], _msgSender()), "Not eligible for refund");
        addedReward = ledger[epochs_[i]][_msgSender()].amount;
      }

      ledger[epochs_[i]][_msgSender()].claimed = true;
      reward += addedReward;

      emit Claim(_msgSender(), epochs_[i], addedReward);
    }

    if (reward > 0) {
      currency.transfer(_msgSender(), reward);
    }
  }

  function resolveRound() external whenNotPaused onlyOwner {
    _requestRandomWords();
  }

  // function executeRound() external whenNotPaused onlyOwner onlyFulfilled(latestRequestId) {
  //   require(genesisStartOnce, "Can only run after genesisStartRound is triggered");

  //   uint256[] memory rawRandomWords = getRandomWords(latestRequestId);

  //   uint256[] memory result = _preFormatRandomWord(rawRandomWords);

  //   _safeEndRound(currentEpoch, latestRequestId, result);
  //   _calculateRewards(currentEpoch);

  //   currentEpoch = currentEpoch + 1;
  //   _safeStartRound(currentEpoch);
  // }

  function executeRound(uint256 requestId_, uint256[] memory randomWords_)
    public
    whenNotPaused
    onlyOwner
    onlyFulfilled(requestId_)
  {
    require(genesisStartOnce, "Can only run after genesisStartRound is triggered");

    uint256[] memory prefixed = _preFormatRandomWord(randomWords_);

    _safeEndRound(currentEpoch, requestId_, prefixed);
    _calculateRewards(currentEpoch);

    currentEpoch = currentEpoch + 1;
    _safeStartRound(currentEpoch);
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
    _unpause();
    emit Unpause(currentEpoch);
  }

  function recoverToken(Currency currency_, uint256 amount_) external onlyOwner {
    require(!(currency_ == currency), "Cannot recover sicbo token");
    currency_.transfer(_msgSender(), amount_);

    emit TokenRecovery(Currency.unwrap(currency_), amount_);
  }

  function _additionalHandler(uint256 requestId_, uint256[] memory randomWords_) internal override {
    executeRound(requestId_, randomWords_);
  }

  function _calculateRewards(uint256 epoch_) internal {
    require(rounds[epoch_].rewardBaseCalAmount == 0 && rounds[epoch_].rewardAmount == 0, "Rewards calculated");
    Round storage round = rounds[epoch_];
    uint256 rewardBaseCalAmount;
    uint256 treasuryAmt;
    uint256 rewardAmount;
    uint256 treasuryFee = sbSettings.treasuryFee;

    if (_isLow(round.closeTotalScore)) {
      rewardBaseCalAmount = round.lowAmount;
      treasuryAmt = (round.totalAmount * treasuryFee) / 10_000;
      rewardAmount = round.totalAmount - treasuryAmt;
    } else if (_isHigh(round.closeTotalScore)) {
      rewardBaseCalAmount = round.highAmount;
      treasuryAmt = (round.totalAmount * treasuryFee) / 10_000;
      rewardAmount = round.totalAmount - treasuryAmt;
    } else {
      rewardBaseCalAmount = 0;
      rewardAmount = 0;
      treasuryAmt = round.totalAmount;
    }
    round.rewardBaseCalAmount = rewardBaseCalAmount;
    round.rewardAmount = rewardAmount;

    treasuryAmount += treasuryAmt;

    emit RewardsCalculated(epoch_, rewardBaseCalAmount, rewardAmount, treasuryAmt);
  }

  function _safeEndRound(uint256 epoch_, uint256 requestId_, uint256[] memory dicesResult_) internal {
    uint256 bufferSeconds = sbSettings.bufferSeconds;

    require(rounds[epoch_].lockAt != 0, "Can only end round after round has locked");
    require(block.timestamp >= rounds[epoch_].closeAt, "Can only end round after closeTimestamp");
    require(block.timestamp <= rounds[epoch_].closeAt + bufferSeconds, "Can only end round within bufferSeconds");

    uint256 totalScore = _calcTotalScore(dicesResult_);
    Round storage round = rounds[epoch_];
    round.requestId = requestId_;
    round.closeDicesResult = dicesResult_;
    round.closeTotalScore = totalScore;
    round.requestedVRF = true;

    emit EndRound(epoch_, requestId_, totalScore);
  }

  function _safeStartRound(uint256 epoch_) internal {
    require(genesisStartOnce, "Can only run after genesisStartRound is triggered");
    require(rounds[epoch_ - 1].closeAt != 0, "Can only start round after round n-1 has ended");
    require(block.timestamp >= rounds[epoch_ - 1].closeAt, "Can only start new round after round n-1 closeTimestamp");
    _startRound(epoch_);
  }

  function _startRound(uint256 epoch_) internal {
    uint256 intervalSeconds = sbSettings.intervalSeconds;
    Round storage round = rounds[epoch_];
    round.startAt = block.timestamp;
    round.lockAt = block.timestamp + intervalSeconds;
    round.closeAt = block.timestamp + (2 * intervalSeconds);
    round.epoch = epoch_;
    round.totalAmount = 0;

    emit StartRound(epoch_);
  }

  function _bettable(uint256 epoch_) internal view returns (bool) {
    return rounds[epoch_].startAt != 0 && rounds[epoch_].lockAt != 0 && block.timestamp > rounds[epoch_].startAt
      && block.timestamp < rounds[epoch_].lockAt;
  }

  function _calcTotalScore(uint256[] memory lockDicesResult_) internal pure returns (uint256 totalScore) {
    for (uint256 i; i < lockDicesResult_.length;) {
      totalScore += lockDicesResult_[i];
      unchecked {
        ++i;
      }
    }
  }

  function _isLow(uint256 totalScore_) internal pure returns (bool isLow) {
    if (totalScore_ > 3 && totalScore_ < 11) {
      isLow = true;
    } else {
      isLow = false;
    }
  }

  function _isHigh(uint256 totalScore_) internal pure returns (bool isHigh) {
    if (totalScore_ > 10 && totalScore_ < 18) {
      isHigh = true;
    } else {
      isHigh = false;
    }
  }

  function _preFormatRandomWord(uint256[] memory rawRandomWords)
    internal
    pure
    returns (uint256[] memory formattedRandomWords)
  {
    formattedRandomWords = new uint256[](rawRandomWords.length);
    for (uint256 i; i < rawRandomWords.length;) {
      formattedRandomWords[i] = rawRandomWords[i] % 6 + 1;
      unchecked {
        ++i;
      }
    }
  }
}
