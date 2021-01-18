// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "../abstract/MoneyPoolAdmin.sol";

/// @dev This contract is an example of how you can use Fountain to fund your own project.
contract YourContract is MoneyPoolAdmin {
    constructor(
        IController _controller,
        IERC20 _want,
        IERC20 _rewardToken,
        UniswapV2Router02 _router
    )
        public
        MoneyPoolAdmin(
            _controller,
            "Your Contract",
            "SYMBOL",
            _rewardToken,
            _router
        )
    {}
}
