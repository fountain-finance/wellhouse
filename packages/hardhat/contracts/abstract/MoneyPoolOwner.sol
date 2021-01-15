// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./../interfaces/IController.sol";

abstract contract MoneyPoolOwner {
    using SafeERC20 for IERC20;

    /// @dev A reference to the Fountain contract.
    IController private controller;

    /// @dev The token this contract wants to be funded in.
    IERC20 public want;

    /// @notice Emitted when a new Controller contract is set.
    event ResetController(
        IController indexed previousController,
        IController indexed newController
    );

    constructor(
        IController _controller,
        string memory _name,
        string memory _symbol,
        IERC20 _want,
        IERC20 _redeemableFor
    ) internal {
        _setController(_controller);
        controller.initializeTickets(_name, _symbol, _redeemableFor);
        want = _want;
    }

    /**
        @notice This allows the contract owner to collect funds from your Money pool.
        @param _mpId The ID of the Money pool to collect funds from.
        @param _amount The amount to tap into.
    */
    function _tapMp(uint256 _mpId, uint256 _amount) internal {
        controller.tapMp(_mpId, _amount, msg.sender);
    }

    /**
        @notice This allows you to reset the Controller contract that's running your Tickets.
        @dev Useful in case you need to switch to an updated Fountain contract
        without redeploying your contract.
        @dev You should also set the Controller for the first time in your constructor.
        @param _newController The new Controller contract.
    */
    function _setController(IController _newController) internal {
        require(
            _newController != IController(0),
            "MoneyPoolOwner::_setController: ZERO_ADDRESS"
        );
        require(
            _newController != controller,
            "MoneyPoolOwner::_setController: NO_CHANGE"
        );
        controller = _newController;
        emit ResetController(controller, _newController);
    }

    /**
        @notice This is how you reconfigure your Money pool.
        @dev The changes will take effect after your active Money pool expires.
        You may way to override this to create new permissions around who gets to decide
        the new Money pool parameters.
        @param _target The new Money pool target amount.
        @param _duration The new duration of your Money pool.
        @param _want The new token that your MoneyPool wants.
        @param _title The title of the Money pool.
        @param _link A link to information about the Money pool.
        @param _bias A number from 70-130 indicating how valuable a Money pool is compared to the owners previous Money pool,
        effectively creating a recency bias.
        If it's 100, each Money pool will have equal weight.
        If the number is 130, each Money pool will be treated as 1.3 times as valuable than the previous, meaning sustainers get twice as much redistribution shares.
        If it's 0.7, each Money pool will be 0.7 times as valuable as the previous Money pool's weight.
        @param _o The percentage of this Money pool's surplus to allocate to the owner.
        @param _b The percentage of this Money pool's surplus to allocate towards a beneficiary address. This can be another contract, or an end user address.
        An example would be a contract that allocates towards a specific purpose, such as Gitcoin grant matching.
        @param _bAddress The address of the beneficiary contract where a specified percentage is allocated.
        @return _mpId The ID of the Money pool that was reconfigured.
    */
    function _configureMp(
        uint256 _target,
        uint256 _duration,
        IERC20 _want,
        string memory _title,
        string memory _link,
        uint256 _bias,
        uint256 _o,
        uint256 _b,
        address _bAddress
    ) internal virtual returns (uint256) {
        // Increse the allowance so that Fountain can transfer excess want tokens from this contract's wallet into a MoneyPool.
        _want.safeIncreaseAllowance(address(controller), 100000000000000E18);

        return
            controller.configureMp(
                _target,
                _duration,
                _want,
                _title,
                _link,
                _bias,
                _o,
                _b,
                _bAddress
            );
    }

    /**
        @notice This allows your contract to accept sustainments.
        @dev You can charge your customers however you like, and they'll keep the surplus if there is any.
        @param _amount The amount you are taking. Your contract must give Fountain allowance.
        @param _sustainer Your contracts end user who is sustaining you.
        Any surplus from your Money pool will be redistributed to this address.
        @return _mpId The ID of the Money pool that was sustained.
    */
    function _sustain(uint256 _amount, address _sustainer)
        internal
        returns (uint256)
    {
        return
            controller.sustainOwner(address(this), _amount, want, _sustainer);
    }
}
