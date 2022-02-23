// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./LiquifyERC20.sol";

contract KeyToken is LiquifyERC20("KeySwap", "KEY") {
    using SafeMath for uint256;
    using Address for address;

    uint16 public MaxLiquifyFee = 500; // 30% max
    uint16 public MaxMarketingFee = 500; // 30% max

    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isKeyPair;

    bool public _applyFeeOnlyOnSell = false; // Fee is applied only when sell tokens or not

    uint16 public _liquifyFee = 300; // Fee for Liquidity
    uint16 public _marketingFee = 200; // Fee for Marketing

    address payable public _marketingWallet;

    bool public _swapAndLiquifyEnabled = true;
    uint256 public _numTokensSellToAddToLiquidity = 100 ether;

    constructor() payable {
        _marketingWallet = payable(_msgSender());

        _isExcludedFromFee[_msgSender()] = true;
    }

    function excludeFromFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function excludeFromKeyPair(address lpAddress) external onlyOwner {
        _isKeyPair[lpAddress] = false;
    }

    function includeInKeyPair(address lpAddress) external onlyOwner {
        _isKeyPair[lpAddress] = true;
    }

    function isKeyPair(address lpAddress) external view returns (bool) {
        return _isKeyPair[lpAddress];
    }

    function setAllFeePercent(uint16 liquifyFee, uint16 marketingFee)
        external
        onlyOwner
    {
        require(liquifyFee <= MaxLiquifyFee, "Liquidity fee overflow");
        require(marketingFee <= MaxMarketingFee, "Buyback fee overflow");
        _liquifyFee = liquifyFee;
        _marketingFee = marketingFee;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        _swapAndLiquifyEnabled = _enabled;
    }

    function setMarketingWallet(address payable newMarketingWallet)
        external
        onlyOwner
    {
        require(newMarketingWallet != address(0), "ZERO ADDRESS");
        _marketingWallet = newMarketingWallet;
    }

    function setNumTokensSellToAddToLiquidity(
        uint256 numTokensSellToAddToLiquidity
    ) external onlyOwner {
        require(numTokensSellToAddToLiquidity > 0, "Invalid input");
        _numTokensSellToAddToLiquidity = numTokensSellToAddToLiquidity;
    }

    function applyFeeOnlyOnSell(bool flag) external onlyOwner {
        _applyFeeOnlyOnSell = flag;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from zero address");
        require(to != address(0), "ERC20: transfer to zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));
        
        // indicates if fee should be deducted from transfer
        // if any account belongs to _isExcludedFromFee account then remove the fee
        bool takeFee = !_isExcludedFromFee[from] &&
            !_isExcludedFromFee[to] &&
            (!_applyFeeOnlyOnSell || _isKeyPair[to]);

        // Swap and liquify also triggered when the tx needs to have fee
        if (!_inSwapAndLiquify && takeFee && _swapAndLiquifyEnabled) {
            if (contractTokenBalance >= _numTokensSellToAddToLiquidity) {
                contractTokenBalance = _numTokensSellToAddToLiquidity;
                // add liquidity, send to marketing wallet
                swapAndLiquify(
                    contractTokenBalance,
                    _marketingFee,
                    _liquifyFee,
                    _marketingWallet
                );
            }
        }

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (takeFee) {
            uint256 feeAmount = amount
                .mul(uint256(_liquifyFee).add(_marketingFee))
                .div(10000);
            if (feeAmount > 0) {
                super._transfer(sender, address(this), feeAmount);
                amount = amount.sub(feeAmount);
            }
        }
        if (amount > 0) {
            super._transfer(sender, recipient, amount);
        }
    }
}
