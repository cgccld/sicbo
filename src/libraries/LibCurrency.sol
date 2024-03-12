// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibNativeTransfer} from "./LibNativeTransfer.sol";

type Currency is address;

using {eq as ==} for Currency global;
using LibCurrency for Currency global;

function eq(Currency self, Currency other) pure returns (bool) {
  return Currency.unwrap(self) == Currency.unwrap(other);
}

/**
 * @title LibCurrency
 * @dev A library for handling different currencies, including native (ETH) and ERC20 tokens.
 */
library LibCurrency {
  /**
   * @dev Emitted when native currency (ETH) is refunded.
   * @param to The address to which the refund is made.
   * @param amount The amount of native currency refunded.
   */
  event Refunded(address indexed to, uint256 amount);

  /**
   * @dev Error thrown when attempting to transfer zero amount.
   * @param currency The currency for which the transfer is attempted.
   */
  error TransferZeroAmount(Currency currency);

  /**
   * @dev Error thrown when attempting to receive zero amount.
   * @param currency The currency for which the receive is attempted.
   */
  error ReceiveZeroAmount(Currency currency);

  /**
   * @dev Error thrown when attempting to transfer insufficient amount.
   * @param currency The currency for which the transfer is attempted.
   */
  error InsufficientAmount(Currency currency);

  /**
   * @dev Error thrown when attempting to receive from an invalid address.
   * @param receiveFrom The address from which the receive is attempted.
   */
  error InvalidReceiveFrom(address receiveFrom);

  using SafeERC20 for IERC20Metadata;
  using LibNativeTransfer for address;

  // Constants
  uint8 private constant NATIVE_DECIMAL = 18;
  Currency internal constant NATIVE = Currency.wrap(address(0x0));

  /**
   * @dev Checks if a given currency is the native currency (ETH).
   * @param currency The currency to check.
   * @return True if the currency is native, false otherwise.
   */
  function isNative(Currency currency) internal pure returns (bool) {
    return currency == NATIVE;
  }

  /**
   * @dev Returns the unique key representing the currency.
   * @param currency The currency to get the key for.
   * @return The key for the currency.
   */
  function key(Currency currency) internal pure returns (uint256) {
    return uint160(Currency.unwrap(currency));
  }

  /**
   * @dev Returns the decimal precision of a given currency.
   * @param currency The currency to get the decimal precision for.
   * @return The decimal precision of the currency.
   */
  function decimal(Currency currency) internal view returns (uint8) {
    if (isNative(currency)) {
      return NATIVE_DECIMAL;
    } else {
      return IERC20Metadata(Currency.unwrap(currency)).decimals();
    }
  }

  /**
   * @dev Returns the balance of the current contract in a given currency.
   * @param currency The currency to check the balance for.
   * @return The balance of the current contract in the specified currency.
   */
  function selfBalance(Currency currency) internal view returns (uint256) {
    address self = address(this);
    if (isNative(currency)) {
      return self.balance;
    } else {
      return IERC20Metadata(Currency.unwrap(currency)).balanceOf(self);
    }
  }

  /**
   * @dev Transfers a given amount of a currency to a specified address.
   * @param currency The currency to transfer.
   * @param to The address to which the transfer is made.
   * @param amount The amount to transfer.
   */
  function transfer(Currency currency, address to, uint256 amount) internal {
    if (amount == 0) revert TransferZeroAmount(currency);
    if (isNative(currency)) {
      to.transfer(amount, gasleft());
    } else {
      IERC20Metadata(Currency.unwrap(currency)).safeTransfer(to, amount);
    }
  }

  /**
   * @dev Receives a given amount of a currency from a specified address.
   * @param currency The currency to receive.
   * @param from The address from which the receive is made.
   * @param amount The amount to receive.
   */
  function receiveFrom(Currency currency, address from, uint256 amount) internal {
    if (amount == 0) revert ReceiveZeroAmount(currency);
    if (isNative(currency)) {
      if (from != msg.sender) revert InvalidReceiveFrom(from);
      if (msg.value < amount) revert InsufficientAmount(NATIVE);

      uint256 refund = msg.value - amount;
      if (refund != 0) {
        from.transfer(refund, gasleft());
        emit Refunded(from, refund);
      }
    } else {
      IERC20Metadata(Currency.unwrap(currency)).transferFrom(from, address(this), amount);
    }
  }
}
