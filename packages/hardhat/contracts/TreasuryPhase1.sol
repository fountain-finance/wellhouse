// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./interfaces/ITreasuryPhase.sol";
import "./Treasury.sol";

contract Phase1 is ITreasuryPhase, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    modifier onlyTreasury {
        require(
            msg.sender == treasuryController,
            "Only the treasury can call this function."
        );
        _;
    }

    /// @notice Amount of tokens issued.
    uint256 public override tokensIssued;

    /// @notice The address where funds are managed
    address public override treasury;

    /// @notice The max amount of tokens to issue.
    uint256 public override cap;

    constructor(uint256 _cap) public {
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
    ) external override onlyTreasury returns (uint256) {
        require(
            _validIssuance(_expectedConvertedAmount),
            "Phase1::convert: INVALID"
        );

        tokensIssued = tokensIssued.add(_expectedConvertedAmount);

        return _expectedConvertedAmount;
    }

    function assignTreasury(OverflowTreasury _treasury) external view override {
        require(
            treasury == address(0),
            "TreasuryPhase1::_assignTreasury: ALREADY_ASSIGNED"
        );
        treasury = _treasury;
    }

    function _validIssuance(uint256 _amount) private view returns (bool) {
        return _amount > 0 && tokensIssued.add(_amount) <= cap;
    }
}
