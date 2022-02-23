// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./AntiBotERC20.sol";
import "./libs/IUniswapAmm.sol";

contract LiquifyERC20 is AntiBotERC20 {
    using SafeMath for uint256;
    using Address for address;

    IUniswapV2Router02 public _swapRouter;

    bool internal _inSwapAndLiquify;

    event LiquifyAndBurned(
        uint256 tokensSwapped,
        uint256 bnbReceived,
        uint256 tokensIntoLiqudity
    );
    event MarketingFeeTrasferred(
        address indexed marketingWallet,
        uint256 tokensSwapped,
        uint256 bnbAmount
    );
    event SwapTokensForBnbFailed(address indexed to, uint256 tokenAmount);
    event LiquifyAndBurnFaied(uint256 tokenAmount, uint256 bnbAmount);

    modifier lockTheSwap() {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }

    constructor(string memory tokenName, string memory tokenSymbol)
        payable
        AntiBotERC20(tokenName, tokenSymbol)
    {
        _swapRouter = IUniswapV2Router02(
            address(0x10ED43C718714eb63d5aA57B78B54704E256024E)
        );
    }

    function setSwapRouter(address newSwapRouter) external onlyOwner {
        require(newSwapRouter != address(0), "Invalid swap router");

        _swapRouter = IUniswapV2Router02(newSwapRouter);
    }

    //to recieve ETH from swapRouter when swaping
    receive() external payable {}

    function swapAndLiquify(
        uint256 amount,
        uint16 marketingFee,
        uint16 liquifyFee,
        address payable marketingWallet
    ) internal lockTheSwap {
        //This needs to be distributed among marketing wallet and liquidity
        if (liquifyFee == 0 && marketingFee == 0) {
            return;
        }

        uint256 marketingAmount = amount.mul(marketingFee).div(
            uint256(marketingFee).add(liquifyFee)
        );
        if (marketingAmount > 0) {
            amount = amount.sub(marketingAmount);
            (uint256 bnbAmount, bool success) = swapTokensForBnb(
                marketingAmount,
                marketingWallet
            );
            if (success) {
                emit MarketingFeeTrasferred(
                    marketingWallet,
                    marketingAmount,
                    bnbAmount
                );
            } else {
                emit SwapTokensForBnbFailed(marketingWallet, marketingAmount);
            }
        }

        if (amount > 0) {
            // split the contract balance into halves
            uint256 half = amount.div(2);
            uint256 otherHalf = amount.sub(half);

            (uint256 bnbAmount, bool success) = swapTokensForBnb(
                half,
                payable(address(this))
            );

            if (!success) {
                emit SwapTokensForBnbFailed(address(this), half);
            }
            // add liquidity to pancakeswap
            if (otherHalf > 0 && bnbAmount > 0 && success) {
                success = addLiquidityAndBurn(otherHalf, bnbAmount);
                if (success) {
                    emit LiquifyAndBurned(half, bnbAmount, otherHalf);
                } else {
                    emit LiquifyAndBurnFaied(otherHalf, bnbAmount);
                }
            }
        }
    }

    function swapTokensForBnb(uint256 tokenAmount, address payable to)
        private
        returns (uint256 bnbAmount, bool success)
    {
        // generate the uniswap pair path of token -> busd
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _swapRouter.WETH();

        _approve(address(this), address(_swapRouter), tokenAmount);

        // capture the target address's current BNB balance.
        uint256 balanceBefore = to.balance;

        // make the swap
        try
            _swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokenAmount,
                0, // accept any amount of BUSD
                path,
                to,
                block.timestamp.add(300)
            )
        {
            // how much BNB did we just swap into?
            bnbAmount = to.balance.sub(balanceBefore);
            success = true;
        } catch (
            bytes memory /* lowLevelData */
        ) {
            // how much BNB did we just swap into?
            bnbAmount = 0;
            success = false;
        }
    }

    function addLiquidityAndBurn(uint256 tokenAmount, uint256 bnbAmount)
        private
        returns (bool success)
    {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(_swapRouter), tokenAmount);

        // add the liquidity
        try
            _swapRouter.addLiquidityETH{value: bnbAmount}(
                address(this),
                tokenAmount,
                0, // slippage is unavoidable
                0, // slippage is unavoidable
                DEAD,
                block.timestamp.add(300)
            )
        {
            success = true;
        } catch (
            bytes memory /* lowLevelData */
        ) {
            success = false;
        }
    }
}
