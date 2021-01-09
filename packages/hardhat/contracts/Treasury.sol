// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./Flow.sol";
import "./Crowdsale.sol";

contract OverflowTreasury {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice The amount of FLOW tokens to sell.
    uint256 public constant CROWDSALE_CAP = 700000E18;

    /// @notice The rate at which to sell FLOW for DAI.
    uint8 public constant CROWDSALE_RATE = 2;

    /// @notice The address of the FLOW ERC20 token.
    IERC20 public flow;

    /// @notice The address of the DAI ERC20 token, which funds will be collected in.
    IERC20 public dai;

    /// @notice The address where funds are managed
    OverflowCrowdsale public crowdsale;

    /// @notice Whether or not the crowdsale has been initialized
    bool public crowdsaleInitialized = false;

    event InitializeCrowdsale();

    constructor(IERC20 _dai) public {
        dai = _dai;
        flow = new Flow(CROWDSALE_CAP);
    }

    function initializeCrowdsale() external {
        require(!crowdsaleInitialized, "OverflowTreasury::initializeCrowdsale");
        crowdsale = new OverflowCrowdsale(
            address(this),
            CROWDSALE_CAP,
            flow,
            dai,
            CROWDSALE_RATE
        );

        // Transfer the FLOW to the crowdsale contract for it to issue.
        flow.safeTransfer(address(crowdsale), CROWDSALE_CAP);

        crowdsaleInitialized = true;
    }
}
