// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// forgefmt: disable-start
import {ISicBo} from "src/interfaces/ISicBo.sol";
import {Currency} from "src/libraries/LibCurrency.sol";
import {SicBoErrors} from "src/interfaces/SicBoErrors.sol";
import {LibRoles as Roles} from "src/libraries/LibRoles.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
// forgefmt: disable-end

contract SicBo is ISicBo, SicBoErrors, Pausable, ReentrancyGuard, AccessControlEnumerable {
  Currency currency;
  AggregatorV3Interface public oracle;

  bool public genesisStartOnce; // default false;

  uint256 public bufferSeconds; // number of seconds for valid execution of a SicBo round
  uint256 public intervalSeconds; // interval in seconds between two SicBo rounds

  uint256 public minBetAmount; // minimum betting amount (denominated in wei)
  uint256 public treasuryFee; // treasury rate (e.g. 200 = 2%, 150 = 1.50%)
  uint256 public treasuryAmount; // treasury amount that was not claimed

  uint256 public currentEpoch; // current epoch for SicBo round

  uint256 public oracleLatestRoundId; // converted from uint80 (Chainlink)
  uint256 public oracleUpdateAllowance; // seconds

  uint256 public constant MAX_TREASURY_FEE = 1000; // 10%

  mapping(uint256 => mapping(address => BetInfo)) public ledger;
  mapping(uint256 => Round) public rounds;
  mapping(address => uint256[]) public userRounds;

  constructor(
    Currency currency_,
    address oracleAddress_,
    address adminAddress_,
    address operatorAddress_,
    uint256 intervalSeconds_,
    uint256 bufferSeconds_,
    uint256 minBetAmount_,
    uint256 oracleUpdateAllowance_,
    uint256 treasuryFee_
  ) {
    currency = currency_;
    treasuryFee = treasuryFee_;
    minBetAmount = minBetAmount_;
    bufferSeconds = bufferSeconds_;
    intervalSeconds = intervalSeconds_;
    oracle = AggregatorV3Interface(oracleAddress_);
    oracleUpdateAllowance = oracleUpdateAllowance_;

    _grantRole(DEFAULT_ADMIN_ROLE, adminAddress_);
    _grantRole(Roles.OPERATOR_ROLE, adminAddress_);
    _grantRole(Roles.TREASURER_ROLE, adminAddress_);

    _grantRole(Roles.OPERATOR_ROLE, operatorAddress_);
  }

  modifier onlyEOA() {
    address sender = _msgSender();
    if (_isContract(sender) || sender != tx.origin) {
      revert SicBo__ProxyUnallowed();
    }
    _;
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
    
    return (
      round.requestedPriceFeed &&
      betInfo.amount != 0 &&
      !betInfo.claimed &&
      (betInfo.position == Position.Low || betInfo.position == Position.High)
    );
  }

  function refundable(uint256 epoch_, address user_) public view returns (bool) {
    BetInfo memory betInfo = ledger[epoch_][user_];
    Round memory round = rounds[epoch_];
    
    return (
      !round.requestedPriceFeed &&
      !betInfo.claimed &&
      block.timestamp > round.closeAt + bufferSeconds &&
      betInfo.amount != 0
    );
  }

  function betLow(uint256 epoch_, uint256 amount_) external whenNotPaused nonReentrant onlyEOA {
    uint256 epoch = epoch_;
    uint256 amount = amount_;
    address sender = _msgSender();

    if (epoch != currentEpoch || !_bettable(epoch)) {
      revert SicBo__RoundNotBettable();
    }
    if (amount < minBetAmount) {
      revert SicBo__BetAmountTooLow();
    }
    if (ledger[epoch][sender].amount != 0) {
      revert SicBo__AlreadyBet();
    }

    currency.receiveFrom(sender, amount);
    // Update round data
    Round storage round = rounds[epoch];
    round.totalAmount += amount;
    round.lowAmount += amount;
    round.numBetLow += 1;

    // Update user data
    BetInfo storage betInfo = ledger[epoch][sender];
    betInfo.position = Position.Low;
    betInfo.amount = amount;
    userRounds[sender].push(epoch);

    emit BetLow(sender, epoch, amount);
  }

  function betHigh(uint256 epoch_, uint256 amount_) external whenNotPaused nonReentrant onlyEOA {
    uint256 epoch = epoch_;
    uint256 amount = amount_;
    address sender = _msgSender();

    if (epoch != currentEpoch || !_bettable(epoch)) {
      revert SicBo__RoundNotBettable();
    }
    if (amount < minBetAmount) {
      revert SicBo__BetAmountTooLow();
    }
    if (ledger[epoch][sender].amount != 0) {
      revert SicBo__AlreadyBet();
    }

    currency.receiveFrom(sender, amount);
    // Update round data
    Round storage round = rounds[epoch];
    round.totalAmount += amount;
    round.highAmount += amount;
    round.numBetHigh += 1;

    // Update user data
    BetInfo storage betInfo = ledger[epoch][sender];
    betInfo.position = Position.High;
    betInfo.amount = amount;
    userRounds[sender].push(epoch);

    emit BetHigh(sender, epoch, amount);
  }

  function claim(uint256[] calldata epochs_) external nonReentrant onlyEOA {
    uint256 epoch;
    uint256 reward;
    address sender = _msgSender();

    for (uint256 i; i < epochs_.length; ++i) {
      epoch = epochs_[i];
      uint256 addedReward = 0;

      if (rounds[epoch].startAt == 0) {
        revert SicBo__RoundNotStarted(epoch);
      }
      if (block.timestamp <= rounds[epoch].closeAt) {
        revert SicBo__RoundNotEnded(epoch);
      }

      if (rounds[epoch].requestedPriceFeed) {
        if (!claimable(epoch, sender)) {
          revert SicBo__NotEligibleForClaim();
        }
        Round memory round = rounds[epoch];
        addedReward = (ledger[epoch][sender].amount * round.rewardAmount) / round.rewardBaseCalAmount;
      } else {
        if (!refundable(epoch, sender)) {
          revert SicBo__NotEligibleForRefund();
        }
        addedReward = ledger[epoch][sender].amount;
      }

      ledger[epoch][sender].claimed = true;
      reward += addedReward;

      emit Claim(sender, epoch, addedReward);
    }

    if (reward > 0) {
      currency.transfer(_msgSender(), reward);
    }
  }

  function executeRound() public whenNotPaused onlyRole(Roles.OPERATOR_ROLE) {
    if (!genesisStartOnce) {
      revert SicBo__GenesisRoundNotTriggered();
    }

    (uint80 currentRoundId, int256 price) = _getPriceFromOracle();
    oracleLatestRoundId = uint256(currentRoundId);

    _safeEndRound(currentEpoch, currentRoundId, price);
    _calculateRewards(currentEpoch);
    unchecked {
      currentEpoch = currentEpoch + 1;
    }
    _safeStartRound(currentEpoch);
  }

  function genesisStartRound() external whenNotPaused onlyRole(Roles.OPERATOR_ROLE) {
    if (genesisStartOnce) {
      revert SicBo__GenesisRoundAlreadyTriggered();
    }
    currentEpoch = currentEpoch + 1;
    _startRound(currentEpoch);
    genesisStartOnce = true;
  }

  function pause() external whenNotPaused onlyRole(Roles.OPERATOR_ROLE) {
    _pause();
    emit Pause(currentEpoch);
  }

  function unpause() external whenPaused onlyRole(Roles.OPERATOR_ROLE) {
    genesisStartOnce = false;
    _unpause();
    emit Unpause(currentEpoch);
  }

  function recoverToken(Currency currency_, uint256 amount_) external onlyRole(Roles.TREASURER_ROLE) {
    if (currency_ == currency) {
      revert SicBo__InvalidRecoverToken();
    }
    currency_.transfer(_msgSender(), amount_);
    emit TokenRecovery(Currency.unwrap(currency_), amount_);
  }

  function claimTreasury() external nonReentrant onlyRole(Roles.TREASURER_ROLE) {
    uint256 currentTreasuryAmount = treasuryAmount;
    treasuryAmount = 0;
    currency.transfer(_msgSender(), currentTreasuryAmount);
    emit TreasuryClaim(currentTreasuryAmount);
  }

  function setBufferAndIntervalSeconds(uint256 bufferSeconds_, uint256 intervalSeconds_) 
    external 
    whenPaused 
    onlyRole(DEFAULT_ADMIN_ROLE) 
  {
    if (bufferSeconds_ > intervalSeconds_) {
      revert SicBo__InvalidBufferSeconds();
    }
    bufferSeconds = bufferSeconds_;
    intervalSeconds = intervalSeconds_;
    emit NewBufferAndIntervalSeconds(bufferSeconds, intervalSeconds);
  }

  function setMinBetAmount(uint256 minBetAmount_) external whenPaused onlyRole(DEFAULT_ADMIN_ROLE) {
    if (minBetAmount_ == 0) {
      revert SicBo__InvalidAmount(minBetAmount_);
    }
    minBetAmount = minBetAmount_;

    emit NewMinBetAmount(currentEpoch, minBetAmount);
  }

  function setOracle(address oracle_) external whenPaused onlyRole(DEFAULT_ADMIN_ROLE) {
    if (oracle_ == address(0)) {
      revert SicBo__NullAddress();
    }
    oracleLatestRoundId = 0;
    oracle = AggregatorV3Interface(oracle_);

    oracle.latestRoundData();

    emit NewOracle(oracle_);
  }

  function setOracleUpdateAllowance(uint256 oracleUpdateAllowance_) external whenPaused onlyRole(DEFAULT_ADMIN_ROLE) {
    oracleUpdateAllowance = oracleUpdateAllowance_;

    emit NewOracleUpdateAllowance(oracleUpdateAllowance_);
  }

  function setTreasuryFee(uint256 treasuryFee_) external whenPaused onlyRole(DEFAULT_ADMIN_ROLE) {
    if (treasuryFee_ > MAX_TREASURY_FEE) {
      revert SicBo__InvalidAmount(treasuryFee_);
    }
    treasuryFee = treasuryFee_;

    emit NewTreasuryFee(currentEpoch, treasuryFee);
  }

  function _calculateRewards(uint256 epoch_) internal {
    uint256 epoch = epoch_;

    if (rounds[epoch].rewardBaseCalAmount != 0 || rounds[epoch].rewardAmount != 0) {
      revert SicBo__RewardsCalculated();
    }

    Round storage round = rounds[epoch];
    uint256 treasuryAmt;
    uint256 rewardAmount;
    uint256 rewardBaseCalAmount;

    if (_isLow(round.diceResult.totalScore)) {
      rewardBaseCalAmount = round.lowAmount;
      treasuryAmt = (round.totalAmount * treasuryFee) / 10_000;
      rewardAmount = round.totalAmount - treasuryAmt;
    } else if (_isHigh(round.diceResult.totalScore)) {
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

    emit RewardsCalculated(epoch, rewardBaseCalAmount, rewardAmount, treasuryAmt);
  }

  function _safeEndRound(uint256 epoch_, uint256 roundId_, int256 price_) internal {
    uint256 epoch = epoch_;

    if (rounds[epoch].closeAt == 0) {
      revert SicBo__RoundNotStarted(epoch);
    }
    if (block.timestamp < rounds[epoch].closeAt) {
      revert SicBo__RoundNotEnded(epoch);
    }
    if (block.timestamp > rounds[epoch].closeAt + bufferSeconds) {
      revert SicBo__EndRoundOutsideBuffer();
    }
    
    (uint256 totalScore, uint256[] memory dices) = _rollDices(epoch_, roundId_, price_);

    Round storage round = rounds[epoch];

    round.roundId = roundId_;
    round.requestedPriceFeed = true;
    round.diceResult = DiceResult({rollAt: block.timestamp, totalScore: totalScore, dices: dices});

    emit EndRound(epoch, roundId_, totalScore);
  }

  function _safeStartRound(uint256 epoch_) internal {
    uint256 epoch = epoch_;

    if (!genesisStartOnce) {
      revert SicBo__GenesisRoundNotTriggered();
    }
    if (rounds[epoch - 1].closeAt == 0) {
      revert SicBo__RoundNotStarted(epoch - 1);
    }
    if (block.timestamp < rounds[epoch - 1].closeAt) {
      revert SicBo__RoundNotEnded(epoch - 1);
    }

    _startRound(epoch);
  }

  function _startRound(uint256 epoch_) internal {
    Round storage round = rounds[epoch_];
    round.epoch = epoch_;
    round.startAt = block.timestamp;
    round.closeAt = block.timestamp + intervalSeconds;

    emit StartRound(epoch_);
  }

  function _bettable(uint256 epoch_) internal view returns (bool) {
    return (
      rounds[epoch_].startAt != 0 &&
      rounds[epoch_].closeAt != 0 &&
      block.timestamp > rounds[epoch_].startAt &&
      block.timestamp < rounds[epoch_].closeAt
    );
  }
  

  function _rollDices(uint256 epoch_, uint256 roundId_, int256 price_)
    internal
    view
    returns (uint256 totalScore, uint256[] memory dices)
  {
    dices = new uint256[](3);
    Round storage round = rounds[epoch_];

    uint256 numOfPlayer = round.numBetLow + round.numBetHigh;
    uint256 avgBetAmount = numOfPlayer == 0 ? 0 : round.totalAmount / numOfPlayer;

    uint256 seed = uint256(
      keccak256(
        abi.encode(
          roundId_,
          price_,
          avgBetAmount,
          block.coinbase,
          block.gaslimit,
          block.timestamp,
          blockhash(block.number - 1),
          blockhash(block.number - 2),
          blockhash(block.number)
        )
      )
    );

    for (uint256 i; i < dices.length;) {
      uint256 dice = uint256(keccak256(abi.encode(seed, i))) % 6 + 1;
      unchecked {
        ++i;
        dices[i] = dice;
        totalScore += dice;
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

  function _getPriceFromOracle() internal view returns (uint80, int256) {
    uint256 leastAllowedTimestamp = block.timestamp + oracleUpdateAllowance;
    (uint80 roundId, int256 price,, uint256 timestamp,) = oracle.latestRoundData();
    require(timestamp <= leastAllowedTimestamp, "Oracle update exceeded max timestamp allowance");
    require(uint256(roundId) > oracleLatestRoundId, "Oracle update roundId must be larger than oracleLatestRoundId");
    return (roundId, price);
  }

  function _isContract(address account) internal view returns (bool isContract) {
    uint256 size;
    assembly {
      size := extcodesize(account)
    }
    isContract = size > 0;
  }
}
