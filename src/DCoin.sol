// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

// "@openzeppelin/contracts": "5.0.1",
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Errors.sol";
import "./Events.sol";
import "./IPancake.sol";
import "./GasHelper.sol";
import "./SwapHelper.sol";

contract DCoin is ERC20Burnable, GasHelper, TokenErrors, TokenEvents, Ownable {
  string public constant URL = "https://www.cryptodelivery.io/";

  uint public constant MAX_SUPPLY = 100_000_000e18;
  uint public constant MIN_AMOUNT_TO_SWAP = 1500e18;
  uint public constant FEE = 300;

  address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
  address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

  mapping(address => bool) public exceptFeeWallets;
  mapping(address => bool) public liquidityWallets;

  address public immutable swapHelper;
  address public immutable mainLiquidityPool;

  bool _reentrance;

  constructor() ERC20("CryptoDeliveryCoin", "DCOIN") Ownable(_msgSender()) {
    PancakeRouter router = PancakeRouter(PANCAKE_ROUTER);
    address liquidityPool = address(PancakeFactory(router.factory()).createPair(WBNB, address(this)));

    mainLiquidityPool = liquidityPool;
    liquidityWallets[liquidityPool] = true;

    SwapHelper swapHelperContract = new SwapHelper();
    swapHelper = address(swapHelperContract);
    exceptFeeWallets[swapHelper] = true;

    _mint(_msgSender(), MAX_SUPPLY);
  }

  receive() external payable {
    revert NotAllowedSendGasToToken();
  }

  function updateExceptFeeWallet(address target, bool status) external onlyOwner {
    exceptFeeWallets[target] = status;
    emit ExceptFeeWalletsUpdated(target, status);
  }

  function updateLiquidityWallet(address target, bool status) external onlyOwner {
    liquidityWallets[target] = status;
    emit LiquidityWalletsUpdated(target, status);
  }

  function _update(address from, address to, uint256 value) internal override {

    bool isLiquiditySender = liquidityWallets[from]; // Buying
    bool isLiquidityReceiver = liquidityWallets[to]; // Selling

    if ((isLiquidityReceiver || isLiquiditySender) && !_reentrance && !exceptFeeWallets[from] && !exceptFeeWallets[to]) {
      _reentrance = true;

      address swapHelperLocal = swapHelper;
      uint fee = (value * FEE) / 10000;
      super._update(from, swapHelperLocal, fee);

      uint swapHelperBalance = balanceOf(swapHelperLocal);
      if (isLiquidityReceiver && swapHelperBalance >= MIN_AMOUNT_TO_SWAP) {
        _operateAutoSwap(swapHelperLocal, swapHelperBalance);
      }

      super._update(from, to, value - fee);
      _reentrance = false;
    } else {
      super._update(from, to, value);
    }
  }

  function _operateAutoSwap(address swapHelperLocal, uint swapHelperBalance) private {
    address liquidityPoolLocal = mainLiquidityPool;

    (uint112 reserve0, uint112 reserve1) = getTokenReserves(liquidityPoolLocal);
    bool reversed = isReversed(liquidityPoolLocal, WBNB);

    if (reversed) {
      uint112 temp = reserve0;
      reserve0 = reserve1;
      reserve1 = temp;
    }

    _update(swapHelperLocal, liquidityPoolLocal, swapHelperBalance);

    uint wbnbAmount = getAmountOut(swapHelperBalance, reserve1, reserve0);
    if (!reversed) {
      swapToken(liquidityPoolLocal, wbnbAmount, 0, swapHelper);
    } else {
      swapToken(liquidityPoolLocal, 0, wbnbAmount, swapHelper);
    }
  }
}
