// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Flow is ERC20 {
    address public treasury;

    modifier onlyTreasury {
        require(
            msg.sender == treasury,
            "Only the treasury can call this function."
        );
        _;
    }

    constructor(uint256 _initialSupply) public ERC20("Overflow", "FLOW") {
        treasury = msg.sender;
        _mint(msg.sender, _initialSupply);
    }

    function mint(uint256 _amount) external onlyTreasury {
        _mint(treasury, _amount);
    }
}
