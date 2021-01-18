// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITicketStoreController {
    /// @notice This event should trigger when a ticket is initialized.
    event IssueTickets(
        address issuer,
        string name,
        string symbol,
        IERC20 rewardToken
    );

    /// @notice This event should trigger when a ticket is redeemed are collected.
    event Redeem(address indexed holder, address _to, uint256 amount);

    event MigrateTickets(address _newController);

    event MintReservedTickets(address minter, address owner);

    event Swap(
        address issuer,
        IERC20 from,
        uint256 amount,
        IERC20 to,
        uint256 swappedAmount
    );

    function issueTickets(
        string calldata _name,
        string calldata _symbol,
        IERC20 _rewardToken
    ) external;

    function redeem(
        address _issuer,
        uint256 _amount,
        address _to
    ) external returns (IERC20 _rewardToken);

    function swap(
        address _issuer,
        IERC20 _from,
        uint256 _amount,
        IERC20 _to,
        uint256 _minSwappedAmount
    ) external;

    function mintReservedTickets(address _issuer) external;

    function migrateTickets(address _newController) external;
}
