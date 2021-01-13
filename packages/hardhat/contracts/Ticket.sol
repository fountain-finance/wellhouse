// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Ticket is ERC20 {
    address fountain;

    modifier onlyFountain {
        require(msg.sender == fountain, "Ticket: UNAUTHORIZED");
        _;
    }

    constructor(string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
    {
        fountain = msg.sender;
    }

    function mint(address _account, uint256 _amount) internal onlyFountain {
        return _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) internal onlyFountain {
        return _burn(_account, _amount);
    }
}
