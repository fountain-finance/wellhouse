// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IController.sol";

import "./MpStore.sol";
import "./TicketStore.sol";

/// All functions in here should be governable with FLOW.
/// Owner should eventually change to a governance contract.
contract Admin is Ownable {
    /// @notice The contract storing all Money pool state variables.
    /// @dev Immutable.
    MpStore public mpStore;

    /// @notice The contract that manages the Tickets.
    /// @dev Immutable.
    TicketStore public ticketStore;

    /// @notice The contract that manages the Tickets.
    /// @dev Immutable.
    IController public controller;

    event WithdrawFunds(IERC20 token, uint256 amount);
    event SetTreasury(ITreasury treasury);
    event AppointTreasury(ITreasury newTreasury);

    constructor(
        IController _controller,
        MpStore _mpStore,
        TicketStore _ticketStore
    ) public {
        controller = _controller;
        controller.setAdmin(address(this));
        mpStore = _mpStore;
        ticketStore = _ticketStore;
        mpStore.claimOwnership();
        ticketStore.claimOwnership();
        ticketStore.grantRole(
            ticketStore.DEFAULT_ADMIN_ROLE(),
            address(controller)
        );
        mpStore.grantRole(
            ticketStore.DEFAULT_ADMIN_ROLE(),
            address(controller)
        );
    }

    function addController(IController _controller) external onlyOwner {
        ticketStore.grantRole(
            ticketStore.DEFAULT_ADMIN_ROLE(),
            address(_controller)
        );
        mpStore.grantRole(
            ticketStore.DEFAULT_ADMIN_ROLE(),
            address(_controller)
        );
        controller = _controller;
        controller.setAdmin(address(this));
    }

    function deprecateController(IController _controller) external onlyOwner {
        ticketStore.revokeRole(
            ticketStore.DEFAULT_ADMIN_ROLE(),
            address(_controller)
        );
        mpStore.revokeRole(
            ticketStore.DEFAULT_ADMIN_ROLE(),
            address(_controller)
        );
    }

    /**
        @notice Allows the owner of the contract to withdraw phase 1 funds.
        @param _amount The amount to withdraw.
    */
    function withdrawFunds(
        uint256 _amount,
        IERC20 _token,
        ITreasury _treasury
    ) external onlyOwner {
        require(
            _treasury != ITreasury(0),
            "Controller::withdrawFunds: BAD_STATE"
        );
        _treasury.withdraw(msg.sender, _token, _amount);
        emit WithdrawFunds(_token, _amount);
    }

    /**
        @notice Replaces the current treasury with a new one. All funds will move over.
        @param _newTreasury The new treasury.
    */
    function appointTreasury(ITreasury _newTreasury) external onlyOwner {
        require(
            _newTreasury != ITreasury(0),
            "Controller::appointTreasury: ZERO_ADDRESS"
        );
        require(
            _newTreasury.controller() == controller,
            "Controller::appointTreasury: INCOMPATIBLE"
        );
        require(
            controller.treasury() != ITreasury(0),
            "Controller::appointTreasury: ZERO_ADDRESS"
        );

        controller.treasury().transition(
            address(_newTreasury),
            controller.getWantTokenAllowList()
        );
        controller.setTreasury(_newTreasury);
        emit AppointTreasury(_newTreasury);
    }
}
