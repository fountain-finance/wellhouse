// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../abstract/MoneyPoolOwner.sol";

/// @dev This contract is an example of how you can use Fountain to fund your own project.
contract YourContract is MoneyPoolOwner {
    constructor(
        IController _controller,
        IERC20 _want,
        IERC20 _rewardToken
    )
        public
        MoneyPoolOwner(
            _controller,
            "Your Contract",
            "SYMBOL",
            _want,
            _rewardToken
        )
    {}
}
