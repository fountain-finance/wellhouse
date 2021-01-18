// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./interfaces/IController.sol";
import "./abstract/MoneyPoolAdmin.sol";

/// All functions in here should be governable with FLOW.
/// Owner should eventually change to a governance contract.
contract Admin is MoneyPoolAdmin {
    using SafeERC20 for IERC20;

    event WithdrawFunds(IERC20 token, uint256 amount, address to);
    event WithdrawFees(IERC20 token, uint256 amount, address to);
    event SetTreasury(ITreasury treasury);
    event AppointTreasury(ITreasury newTreasury);

    /** 
      @param _controller The controller that is being administered.
    */
    constructor(
        IController _controller,
        ITreasury _treasury,
        string memory _name,
        string memory _symbol,
        IERC20 _rewardToken,
        UniswapV2Router02 _router
    )
        public
        MoneyPoolAdmin(_controller, _name, _symbol, _rewardToken, _router)
    {
        controller.setTreasury(_treasury);
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
        require(_treasury != ITreasury(0), "Admin::withdrawFunds: BAD_STATE");
        _treasury.withdraw(_to, _token, _amount);
        emit WithdrawFunds(_token, _amount, _to);
    }

    /**
        @notice Allows the owner of the contract to withdraw fees paid to it by the controller.
        @param _amount The amount to withdraw.
        @param _token The token to withdraw.
        @param _to The address being withdrawn to.
    */
    function withdrawSurplus(
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
            "Admin::appointTreasury: ZERO_ADDRESS"
        );
        require(
            _newTreasury.controller() == address(controller),
            "Admin::appointTreasury: INCOMPATIBLE"
        );
        require(
            controller.treasury() != ITreasury(0),
            "Admin::appointTreasury: ZERO_ADDRESS"
        );

        controller.setTreasury(_newTreasury);
        emit AppointTreasury(_newTreasury);
    }
}
