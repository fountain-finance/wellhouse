// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./interfaces/ITreasuryPhase.sol";

contract TreasuryPhase1 is ITreasuryPhase {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice The address that deployed this contract.
    address public override deployer;
    /// @notice Amount of tokens issued.
    uint256 public override tokensIssued;
    /// @notice The address where funds are managed
    address public override treasury;
    /// @notice The max amount of tokens to issue.
    uint256 public override cap;

    constructor(uint256 _cap) public {
        cap = _cap;
        tokensIssued = 0;
        deployer = msg.sender;
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
    ) external override returns (uint256) {
        require(
            msg.sender == treasury,
            "TreasuryPhase1::transform: UNAUTHORIZED"
        );
        require(
            _validIssuance(_expectedConvertedAmount),
            "TreasuryPhase1::transform: INVALID"
        );
        tokensIssued = tokensIssued.add(_expectedConvertedAmount);
        return _expectedConvertedAmount;
    }

    function assignTreasury(address _treasury) external override {
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
