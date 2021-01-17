// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "./IStore.sol";
import "../libraries/MoneyPool.sol";

interface IMpStore is IStore {
    function getMp(uint256 _mpId) external view returns (MoneyPool.Data memory);

    function getQueuedMp(address _owner)
        external
        view
        returns (MoneyPool.Data memory);

    function getCurrentMp(address _owner)
        external
        view
        returns (MoneyPool.Data memory _mp);

    function getLatestMp(address _owner)
        external
        view
        returns (MoneyPool.Data memory _mp);

    function getTappableAmount(uint256 _mpId) external view returns (uint256);

    function getWantedTokens(address _owner, IERC20 _rewardToken)
        external
        view
        returns (IERC20[] memory);

    function trackAcceptedToken(
        address _owner,
        IERC20 _redeemableToken,
        IERC20 _token
    ) external;

    function clearWantedTokens(address _owner, IERC20 _token) external;

    function ensureActiveMp(address _owner)
        external
        returns (MoneyPool.Data memory _mp);

    function ensureStandbyMp(address _owner)
        external
        returns (MoneyPool.Data memory _mp);

    function saveMp(MoneyPool.Data calldata _mp) external;
}
