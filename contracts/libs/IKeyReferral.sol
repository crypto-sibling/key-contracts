// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IKeyReferral {
    /**
     * @dev Record referral.
     */
    function recordReferrer(address _account, address _referrer) external;

    /**
     * @dev Record referral reward.
     */
    function addReferralReward(address _referrer, uint256 _reward) external;

    /**
     * @dev Get the account that referred the user.
     */
    function getReferrer(address _account) external view returns (address);

    /**
     * @dev Get the total earned of a referrer
     */
    function getReferrerEarned(address _account) external view returns (uint256);

    /**
     * @notice Get referred users count by an account
     */
    function getReferredUserCount(address _account) external view returns (uint256);
}
