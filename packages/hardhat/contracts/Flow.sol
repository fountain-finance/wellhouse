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
    event AssignTreasury(address treasury);
    event ReplaceTreasury(address treasury);

    constructor() public ERC20("Overflow", "FLOW") {}

    function mint(uint256 _amount) external onlyTreasury {
        _mint(treasury, _amount);
    }

    function burn(uint256 _amount) external onlyTreasury {
        _burn(treasury, _amount);
    }

    function assignTreasury(address _treasury) external {
        require(
            treasury == address(0),
            "Flow::assignTreasury: ALREADY_ASSIGNED"
        );
        treasury = _treasury;
        emit AssignTreasury(_treasury);
    }

    function replaceTreasury(address _newTreasury) external onlyTreasury {
        require(
            _newTreasury != address(0),
            "Flow::replaceTreasury: ZERO_ADDRESS"
        );
        treasury = _newTreasury;
        emit ReplaceTreasury(_newTreasury);
    }
}
