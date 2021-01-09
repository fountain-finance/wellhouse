// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Flow is ERC20 {
    constructor(uint256 _initialSupply) public ERC20("Overflow", "FLOW", 18) {
        _mint(msg.sender, _initialSupply);
    }
}
