// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITicketStand {
    /// @notice This event should trigger when a ticket is initialized.
    event InitializeTicket(
        address owner,
        string name,
        string symbol,
        IERC20 redeemableFor
    );

    /// @notice This event should trigger when a ticket is redeemed are collected.
    event Redeem(address indexed holder, uint256 amount);

    function initializeTicket(
        string calldata _name,
        string calldata _symbol,
        IERC20 _redeemableFor
    ) external;

    function redeem(address _owner, uint256 _amount) external;
}
