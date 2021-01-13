// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../libraries/MoneyPool.sol";
import "../Treasury.sol";

interface IFountain {
    function latestMpId(address _owner) external view returns (uint256);

    function mpCount() external view returns (uint256);

    /// @notice This event should trigger when a Money pool is configured.
    event ConfigureMp(
        uint256 indexed mpId,
        address indexed owner,
        uint256 indexed target,
        uint256 duration,
        IERC20 want,
        string title,
        string link,
        uint8 bias,
        uint8 o,
        uint8 b,
        address bAddress
    );

    /// @notice This event should trigger when a Money pool is sustained.
    event SustainMp(
        uint256 indexed mpId,
        address indexed owner,
        address indexed beneficiary,
        address sustainer,
        uint256 amount,
        address want
    );

    /// @notice This event should trigger when redistributions are collected.
    event CollectRedistributions(address indexed sustainer, uint256 amount);

    /// @notice This event should trigger when sustainments are collected.
    event TapMp(
        uint256 indexed mpId,
        address indexed owner,
        address indexed beneficiary,
        uint256 amount,
        IERC20 want
    );

    function getMp(uint256 _mpId)
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

    function getTappableAmount(uint256 _mpId)
        external
        view
        returns (uint256 _amount);

    function getRedistributableAmount(address _beneficiary, address _owner)
        external
        view
        returns (uint256 _amount);

    function configureMp(
        uint256 _target,
        uint256 _duration,
        IERC20 _want,
        string memory _title,
        string memory _link,
        uint8 bias,
        uint8 _o,
        uint8 _b,
        address _bAddress,
        string memory _tokenName,
        string memory _tokenSymbol
    ) external returns (uint256 _mpId);

    function sustainOwner(
        address _owner,
        uint256 _amount,
        IERC20 _want,
        address _beneficiary,
        uint256 _convertedFlowAmount
    ) external returns (uint256 _mpId);

    function collectRedistributions(address _owner, uint256 _amount) external;

    function tapMp(
        uint256 _mpId,
        uint256 _amount,
        address _beneficiary
    ) external;

    function overthrowTreasury(OverflowTreasury _newTreasury) external;

    function withdrawPhase1Funds(uint256 _amount) external;

    function allocatePhase2Funds(
        address _owner,
        uint256 _amount,
        uint256 _want,
        address _beneficiary,
        uint256 _convertedFlowAmount
    ) external;
}
