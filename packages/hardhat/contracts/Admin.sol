// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./interfaces/IController.sol";

//TODO make this a Money pool owner. Make a role for devs, and a role for stakers.
//TODO this needs to call "redeem" instead of withdraw. Proceeds go to a money pool.

/// All functions in here should be governable with FLOW.
/// Owner should eventually change to a governance contract.
contract Admin is Ownable {
    using SafeERC20 for IERC20;

    /// @notice The contract that manages the Tickets.
    /// @dev Immutable.
    IController public controller;

    event WithdrawFunds(IERC20 token, uint256 amount, address to);
    event WithdrawFees(IERC20 token, uint256 amount, address to);
    event SetTreasury(ITreasury treasury);
    event AppointTreasury(ITreasury newTreasury);

    /** 
      @param _controller The controller that is being administered.
    */
    constructor(IController _controller, ITreasury _treasury) public {
        controller = _controller;
        controller.setAdmin(address(this));
        IMpStore _mpStore = controller.mpStore();
        ITicketStore _ticketStore = controller.ticketStore();
        _mpStore.claimOwnership();
        _ticketStore.claimOwnership();
        _ticketStore.grantRole_(
            _ticketStore.DEFAULT_ADMIN_ROLE_(),
            address(controller)
        );
        _mpStore.grantRole_(
            _mpStore.DEFAULT_ADMIN_ROLE_(),
            address(controller)
        );
        controller.setTreasury(_treasury);
    }

    function addController(IController _controller) external onlyOwner {
        IMpStore _mpStore = _controller.mpStore();
        ITicketStore _ticketStore = _controller.ticketStore();
        _ticketStore.grantRole_(
            _ticketStore.DEFAULT_ADMIN_ROLE_(),
            address(_controller)
        );
        _mpStore.grantRole_(
            _mpStore.DEFAULT_ADMIN_ROLE_(),
            address(_controller)
        );
        controller = _controller;
        controller.setAdmin(address(this));
    }

    function deprecateController(IController _controller) external onlyOwner {
        IMpStore _mpStore = controller.mpStore();
        ITicketStore _ticketStore = controller.ticketStore();
        _ticketStore.revokeRole_(
            _ticketStore.DEFAULT_ADMIN_ROLE_(),
            address(_controller)
        );
        _mpStore.revokeRole_(
            _ticketStore.DEFAULT_ADMIN_ROLE_(),
            address(_controller)
        );
    }

    /**
        @notice Allows the owner of the contract to withdraw funds allocated to it from the treasury.
        @param _amount The amount to withdraw.
        @param _token The token being withdrawn.
        @param _to The address being withdraw to.
        @param _treasury The treasury to withdraw from.
    */
    function withdrawFunds(
        uint256 _amount,
        IERC20 _token,
        address _to,
        ITreasury _treasury
    ) external onlyOwner {
        require(
            _treasury != ITreasury(0),
            "Controller::withdrawFunds: BAD_STATE"
        );
        _treasury.withdraw(_to, _token, _amount);
        emit WithdrawFunds(_token, _amount, _to);
    }

    /**
        @notice Allows the owner of the contract to withdraw fees paid to it by the controller.
        @param _amount The amount to withdraw.
        @param _token The token being withdrawn.
        @param _to The address being withdraw to.
    */
    function withdrawFees(
        uint256 _amount,
        IERC20 _token,
        address _to
    ) external onlyOwner {
        require(_to != address(0), "Admin::withdrawFees ZERO_ADDRESS");
        _token.safeTransfer(_to, _amount);
        emit WithdrawFees(_token, _amount, _to);
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
            _newTreasury.controller() == address(controller),
            "Controller::appointTreasury: INCOMPATIBLE"
        );
        require(
            controller.treasury() != ITreasury(0),
            "Controller::appointTreasury: ZERO_ADDRESS"
        );

        controller.setTreasury(_newTreasury);
        emit AppointTreasury(_newTreasury);
    }
}
