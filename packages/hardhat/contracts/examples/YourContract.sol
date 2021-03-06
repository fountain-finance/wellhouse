// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../abstract/MoneyPoolOwner.sol";

/// @dev This contract is an example of how you can use Fountain to fund your own project.
contract YourContract is MoneyPoolOwner {
    constructor(IFountain _fountain, IERC20 _want)
        public
        MoneyPoolOwner(_fountain, 10000, 60, _want, "Some title", "some.link")
    {}
}
