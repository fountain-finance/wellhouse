// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract OverflowCrowdsale {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice Amount of tokens issued.
    uint256 public tokensIssued;

    /// @notice The max amount of tokens to issue.
    uint256 public cap;

    /// @notice The address of the token being issued.
    IERC20 public token;

    /// @notice The address of the token which this crowdsale wants.
    IERC20 public want;

    /// @notice The rate at which this crowdsale is willing to sell the issued token for the want token.
    uint8 public rate;

    /// @notice The address where funds are managed
    address public treasury;

    /**
     * Event for token issuing
     * @param beneficiary Who the tokens were issued to
     * @param value The amount of `want` token paid for purchase
     * @param amount The amount of tokens issued
     * @param rate The conversion rate of issued tokens to want tokens.
     */
    event Issue(
        address indexed beneficiary,
        uint256 value,
        uint256 amount,
        uint8 rate
    );

    constructor(
        address _treasury,
        uint256 _cap,
        IERC20 _token,
        IERC20 _want,
        uint8 _rate
    ) public {
        treasury = _treasury;
        cap = _cap;
        token = _token;
        want = _want;
        rate = _rate;
        tokensIssued = 0;
    }

    /** 
      @notice Issue token to the message sender.
      @param _amount The amount of `want` tokens to use for issuing.
      @return _issued The amount of tokens issued.
    */
    function issue(uint256 _amount) external returns (uint256 _issued) {
        _issued = _amount.mul(rate);

        require(_validIssuance(_issued), "OverflowTreasury::sell: INVALID");

        want.safeTransferFrom(msg.sender, treasury, _amount);
        token.safeTransfer(msg.sender, _issued);

        tokensIssued = tokensIssued.add(_issued);

        emit Issue(msg.sender, _amount, _issued, rate);
    }

    function _validIssuance(uint256 _amount) private view returns (bool) {
        return _amount > 0 && tokensIssued.add(_amount) <= cap;
    }
}
