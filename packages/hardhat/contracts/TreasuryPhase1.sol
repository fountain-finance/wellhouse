// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./interfaces/ITreasuryPhase.sol";

contract Phase1 is ITreasuryPhase {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    modifier onlyTreasuryController {
        require(
            msg.sender == treasuryController,
            "Only the treasury can call this function."
        );
        _;
    }

    /// @notice Amount of tokens issued.
    uint256 public override tokensIssued;

    /// @notice The address where funds are managed
    address public override treasuryController;

    /// @notice The max amount of tokens to issue.
    uint256 public cap;

    constructor(uint256 _cap, IERC20 _token) public {
        treasuryController = msg.sender;
        cap = _cap;
        tokensIssued = 0;
    }

    /** 
      @notice Convert the specified amount into tokens.
      @param _token The token being converted.
      @param _amount The amount of tokens to use for issuing.
      @param _expectedConvertedAmount The amount of tokens expected in exchange.
      @return _converted The amount of tokens issued.
    */
    function transform(
        uint256 _amount,
        IERC20 _token,
        uint256 _expectedConvertedAmount
    ) external override onlyTreasuryController returns (uint256) {
        require(
            _validIssuance(_expectedConvertedAmount),
            "Phase1::convert: INVALID"
        );

        tokensIssued = tokensIssued.add(_expectedConvertedAmount);

        return _expectedConvertedAmount;
    }

    function _validIssuance(uint256 _amount) private view returns (bool) {
        return _amount > 0 && tokensIssued.add(_amount) <= cap;
    }
}
