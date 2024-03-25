// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface SicBoErrors {
  error SicBo__ProxyUnallowed();
  error SicBo__RoundNotBettable();
  error SicBo__BetAmountTooLow();
  error SicBo__AlreadyBet();
  error SicBo__RoundNotStarted(uint256 epoch);
  error SicBo__RoundNotEnded(uint256 epoch);
  error SicBo__NotEligibleForClaim();
  error SicBo__NotEligibleForRefund();
  error SicBo__GenesisRoundNotTriggered();
  error SicBo__GenesisRoundAlreadyTriggered();
  error SicBo__InvalidRecoverToken();
  error SicBo__EndRoundOutsideBuffer();
  error SicBo__RewardsCalculated();
  error SicBo__InvalidBufferSeconds();
  error SicBo__NullAddress();
  error SicBo__InvalidAmount(uint256 amount);
  error SicBo__OnlyNFTHolder();
}
