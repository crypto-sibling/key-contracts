// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./libs/IERC20.sol";
import "./libs/SafeERC20.sol";
import "./libs/SafeMath.sol";
import "./libs/IKeyReferral.sol";
import "./libs/Ownable.sol";

contract KeyReferral is IKeyReferral, Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    mapping(address => bool) private operators;
    mapping(address => address) private referrers; // user address => referrer address
    mapping(address => uint256) private referredCounts; // referred user count by referrer
    mapping(address => uint256) private referrerRewards; // referrer address => referrer rewards
    uint256 public totalReferralRewards;

    event NewReferrer(address indexed user, address indexed referrer);
    event ReferrerRewarded(address indexed referrer, uint256 commission);
    event OperatorUpdated(address indexed operator, bool indexed status);

    function recordReferrer(address _user, address _referrer)
        external
        override
    {
        require(operators[_msgSender()], "Caller is not the operator");
        if (
            _user != address(0) &&
            _referrer != address(0) &&
            _user != _referrer &&
            referrers[_user] == address(0)
        ) {
            referrers[_user] = _referrer;
            referredCounts[_referrer] = referredCounts[_referrer].add(1);
            emit NewReferrer(_user, _referrer);
        }
    }

    function addReferralReward(address _referrer, uint256 _reward)
        external
        override
    {
        require(operators[_msgSender()], "Caller is not the operator");
        if (_referrer != address(0) && _reward > 0) {
            referrerRewards[_referrer] = referrerRewards[_referrer].add(
                _reward
            );
            totalReferralRewards = totalReferralRewards.add(_reward);
            emit ReferrerRewarded(_referrer, _reward);
        }
    }

    /**
     * @notice check if the account is operator
     */
    function isOperator(address _account) external view returns (bool) {
        return operators[_account];
    }

    /**
     * @notice Get the referrer address that referred the user
     */
    function getReferrer(address _user)
        external
        view
        override
        returns (address)
    {
        return referrers[_user];
    }

    /**
     * @notice Get the earned amount of a referrer
     */
    function getReferrerEarned(address _account)
        external
        view
        override
        returns (uint256)
    {
        return referrerRewards[_account];
    }

    /**
     * @notice Get the referred users count
     */
    function getReferredUserCount(address _account)
        external
        view
        override
        returns (uint256)
    {
        return referredCounts[_account];
    }

    /**
     * @notice Update operator
     */
    function updateOperator(address _operator, bool _status)
        external
        onlyOwner
    {
        operators[_operator] = _status;
        emit OperatorUpdated(_operator, _status);
    }

    /**
     * @notice withdraw wrong tokens from this contract
     */
    function drainBEP20Token(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOwner {
        _token.safeTransfer(_to, _amount);
    }
}
