// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import {
    UniswapV2Router02
} from "@uniswap/v2-periphery/contracts/UniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./interfaces/ITreasury.sol";
import "./interfaces/IController.sol";

import "./Admin.sol";

contract Treasury is ITreasury {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    modifier onlyController {
        require(msg.sender == address(controller), "Treasury: UNAUTHORIZED");
        _;
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "Treasury: UNAUTHORIZED");
        _;
    }

    /// @notice Amount each tokens from Phase 1 and Phase 2 that have yet to be withdrawn.
    mapping(IERC20 => uint256) public override adminFunds;

    /// @notice The controller that this Treasury services.
    address public override controller;

    /// @notice The admin that this Treasury belongs to.
    address public override admin;

    //TODO
    UniswapV2Router02 public router;

    constructor(UniswapV2Router02 _router) public {
        router = _router;
    }

    function setController(address _controller) external {
        require(
            controller == address(0),
            "Treasury::setController: ALREADY_SET"
        );
        controller = _controller;
    }

    function setAdmin(address _admin) external {
        require(admin == address(0), "Treasury::setAdmin: ALREADY_SET");
        admin = _admin;
    }

    function swap(
        IERC20 _from,
        uint256 _amount,
        IERC20 _to,
        uint256 _minSwappedAmount
    ) external override onlyController returns (uint256 _resultingAmount) {
        require(
            _from.approve(address(router), _amount),
            "MoneyPoolAdmin::redeemTickets: APPROVE_FAILED."
        );

        address[] memory path = new address[](2);
        path[0] = address(_from);
        path[1] = router.WETH();
        path[2] = address(_to);
        uint256[] memory _amounts =
            router.swapExactTokensForTokens(
                _amount,
                _minSwappedAmount,
                path,
                address(this),
                block.timestamp
            );
        emit Swap(_from, _amount, _to, _resultingAmount);
    }

    function payout(
        address _to,
        IERC20 _token,
        uint256 _amount
    ) external override onlyController {
        _token.safeTransfer(_to, _amount);
    }

    function withdraw(
        address _to,
        IERC20 _token,
        uint256 _amount
    ) external override onlyAdmin {
        require(
            adminFunds[_token] >= _amount,
            "Treasury::withdraw: INSUFFICIENT_FUNDS"
        );
        adminFunds[_token] = adminFunds[_token].sub(_amount);
        _token.safeTransfer(_to, _amount);
    }

    function peacefulTransition(address _newTreasury, IERC20[] calldata _tokens)
        external
        override
        onlyController
    {
        for (uint256 i = 0; i < _tokens.length; i++) {
            _tokens[i].safeTransfer(
                _newTreasury,
                _tokens[i].balanceOf(address(this))
            );
        }
        emit Transition(_newTreasury);
    }
}
