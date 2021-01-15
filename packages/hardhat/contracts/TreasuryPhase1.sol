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

    /// @notice The max amount of tokens to issue.
    uint256 public constant override cap = 700000E18;

    /// @notice The address that deployed this contract.
    address public override deployer;

    /// @notice Amount of each token issued so far.
    mapping(IERC20 => uint256) public override tokensIssued;

    /// @notice The address where funds are managed
    address public override treasury;

    constructor() public {
        deployer = msg.sender;
    }

    /**
      @notice Convert the specified amount into tokens.
      @param _from The token being converted from.
      @param _amount The amount of tokens to use for issuing.
      @param _to The token being converted to.
      @param _expectedTransformAmount The amount of tokens expected in exchange.
      @return _converted The amount of tokens issued.
    */
    function transform(
        IERC20 _from,
        uint256 _amount,
        IERC20 _to,
        uint256 _expectedTransformAmount
    ) external override returns (uint256) {
        require(
            msg.sender == treasury,
            "TreasuryPhase1::transform: UNAUTHORIZED"
        );
        require(
            _validIssuance(_expectedTransformAmount, _to),
            "TreasuryPhase1::transform: INVALID"
        );
        tokensIssued[_to] = tokensIssued[_to].add(_expectedTransformAmount);
        return _expectedTransformAmount;
    }

    function assignTreasury(address _treasury) external override {
        require(
            treasury == address(0),
            "TreasuryPhase1::_assignTreasury: ALREADY_ASSIGNED"
        );
        treasury = _treasury;
    }

    function _validIssuance(uint256 _amount, IERC20 _token)
        private
        view
        returns (bool)
    {
        return _amount > 0 && tokensIssued[_token].add(_amount) <= cap;
    }
}
