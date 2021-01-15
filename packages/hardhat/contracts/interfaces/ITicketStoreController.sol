// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITicketStoreController {
    /// @notice This event should trigger when a ticket is initialized.
    event InitializeTickets(
        address owner,
        string name,
        string symbol,
        IERC20 rewardToken
    );

    /// @notice This event should trigger when a ticket is redeemed are collected.
    event Redeem(address indexed holder, uint256 amount);

    event MigrateTickets(address _newController);

    event MintReservedTickets(address minter, address owner);

    event Transform(
        address owner,
        IERC20 from,
        uint256 amount,
        IERC20 to,
        uint256 transformedAmount
    );

    function initializeTickets(
        string calldata _name,
        string calldata _symbol,
        IERC20 _rewardToken
    ) external;

    function redeem(address _owner, uint256 _amount) external;

    function transform(
        address _owner,
        IERC20 _from,
        uint256 _amount,
        IERC20 _to,
        uint256 _expectedTransformedAmount
    ) external;

    function mintReservedTickets(address _owner) external;

    function migrateTickets(address _newController) external;

    function appointTicketStandAdmin(address _newAdmin) external;
}
