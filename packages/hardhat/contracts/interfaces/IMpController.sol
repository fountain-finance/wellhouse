// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ITreasury.sol";

interface IMpController {
    /// @notice This event should trigger when a Money pool is configured.
    event ConfigureMp(
        uint256 indexed mpId,
        address indexed owner,
        uint256 indexed target,
        uint256 duration,
        IERC20 want,
        string title,
        string link,
        uint256 bias,
        uint256 o,
        uint256 b,
        address bAddress
    );

    /// @notice This event should trigger when a Money pool is sustained.
    event SustainMp(
        uint256 indexed mpId,
        address indexed owner,
        address indexed beneficiary,
        address sustainer,
        uint256 amount,
        IERC20 want
    );

    /// @notice This event should trigger when sustainments are collected.
    event TapMp(
        uint256 indexed mpId,
        address indexed owner,
        address indexed beneficiary,
        uint256 amount,
        IERC20 want
    );

    function configureMp(
        uint256 _target,
        uint256 _duration,
        IERC20 _want,
        string calldata _title,
        string calldata _link,
        uint256 bias,
        uint256 _o,
        uint256 _b,
        address _bAddress
    ) external returns (uint256 _mpId);

    function sustainOwner(
        address _owner,
        uint256 _amount,
        IERC20 _want,
        address _beneficiary
    ) external returns (uint256 _mpId);

    function tapMp(
        uint256 _mpId,
        uint256 _amount,
        address _beneficiary
    ) external;

    function cleanTrackedAcceptedTokens(address _owner, IERC20 _token) external;

    function appointMpStoreAdmin(address _newAdmin) external;
}
