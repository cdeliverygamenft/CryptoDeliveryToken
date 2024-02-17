// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface TokenEvents {
  event LiquidityWalletsUpdated(address indexed wallet, bool status);
  event ExceptFeeWalletsUpdated(address indexed wallet, bool status);
}
