// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    uint256 INITIAL_SUPPLY = 100000;

    constructor() public ERC20("Dai", "DAI") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function gimme(uint256 _amount) external {
        _mint(msg.sender, _amount);
    }
}
