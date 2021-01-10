// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../libraries/MoneyPool.sol";

interface IFountain {
    function latestMpNumber(address _owner) external view returns (uint256);

    function mpCount() external view returns (uint256);

    /// @notice This event should trigger when a Money pool is configured.
    event ConfigureMp(
        uint256 indexed mpNumber,
        address indexed owner,
        uint256 indexed target,
        uint256 duration,
        IERC20 want,
        string title,
        string link
    );

    /// @notice This event should trigger when a Money pool is sustained.
    event SustainMp(
        uint256 indexed mpNumber,
        address indexed owner,
        address indexed beneficiary,
        address sustainer,
        uint256 amount
    );

    /// @notice This event should trigger when redistributions are collected.
    event CollectRedistributions(address indexed sustainer, uint256 amount);

    /// @notice This event should trigger when sustainments are collected.
    event TapMp(
        uint256 indexed mpNumber,
        address indexed owner,
        address indexed beneficiary,
        uint256 amount,
        IERC20 want
    );

    function getMp(uint256 _mpNumber)
        external
        view
        returns (MoneyPool.Data memory _mp);

    function getQueuedMp(address _owner)
        external
        view
        returns (MoneyPool.Data memory _mp);

    function getCurrentMp(address _owner)
        external
        view
        returns (MoneyPool.Data memory _mp);

    function getSustainment(uint256 _mpNumber, address _sustainer)
        external
        view
        returns (uint256 _amount);

    function getTappableAmount(uint256 _mpNumber)
        external
        view
        returns (uint256 _amount);

    function getTrackedRedistribution(uint256 _mpNumber, address _sustainer)
        external
        view
        returns (uint256 _amount);

    function getAllTrackedRedistribution(
        address _sustainer,
        bool _includesActive
    ) external view returns (uint256 _amount);

    function configureMp(
        uint256 _target,
        uint256 _duration,
        IERC20 _want,
        string calldata _title,
        string calldata _link
    ) external returns (uint256 _mpNumber);

    function sustainOwner(
        address _owner,
        uint256 _amount,
        IERC20 _want,
        address _beneficiary,
        uint256 _convertedFlowAmount
    ) external returns (uint256 _mpNumber);

    function collectAllRedistributions() external returns (uint256 _amount);

    function collectRedistributionsFromOwner(address _owner)
        external
        returns (uint256 _amount);

    function collectRedistributionsFromOwners(address[] calldata _owner)
        external
        returns (uint256 _amount);

    function tapMp(
        uint256 _mpNumber,
        uint256 _amount,
        address _beneficiary
    ) external returns (bool _success);
}
