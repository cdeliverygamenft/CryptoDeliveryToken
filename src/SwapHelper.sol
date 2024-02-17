// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;


// "@openzeppelin/contracts": "5.0.1",
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SwapHelper {

  address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

  address feeReceiver;

  constructor() {
    feeReceiver = tx.origin;
    IERC20(WBNB).approve(feeReceiver, type(uint).max);
  }

  function withdraw() public {
    uint balance = IERC20(WBNB).balanceOf(address(this));
    IERC20(WBNB).transfer(feeReceiver, balance);
  }
}
