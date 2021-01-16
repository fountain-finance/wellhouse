// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./interfaces/ITreasury.sol";
import "./interfaces/IController.sol";

import "./Flow.sol";

contract Treasury is ITreasury {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    modifier onlyController {
        require(msg.sender == address(controller), "Treasury: UNAUTHORIZED");
        _;
    }

    /// @notice The treasury behaves in different ways depending on the phase.
    /// @dev The phase is determined by the amount of surplus in the system.
    enum Phase {None, One, Two, Three}

    /// @notice The rate at which to issue FLOW for DAI in phase 1.
    uint8 public constant PHASE_1_RATE = 2;
    /// @notice The rate at which to issue FLOW for DAI in phase 2.
    uint8 public constant PHASE_2_RATE = 1;
    /// @notice The coin to accept during the phased issuance.
    IERC20 public issuanceToken;
    /// @notice The address of the FLOW ERC20 token.
    Flow public flow;
    /// @notice The contract managing Phase 1 token swaps.
    ITreasuryPhase public override phase1;
    /// @notice The contract managing Phase 2 token swaps.
    ITreasuryPhase public override phase2;
    /// @notice The contract managing Phase 3 token swaps.
    ITreasuryPhase public override phase3;
    /// @notice Amount each tokens from Phase 1 and Phase 2 that have yet to be withdrawn.
    mapping(IERC20 => uint256) public override withdrawableFunds;
    /// @notice The controller that this Treasury belongs to.
    IController public override controller;

    constructor(Flow _flow, IController _controller) public {
        controller = _controller;
        controller.setTreasury(this);
        flow = _flow;
    }

    function initializePhase1(ITreasuryPhase _phase1) external {
        require(
            _getPhase(issuanceToken) == Phase.None ||
                address(phase1) == address(0),
            "Treasury::initializePhase1: ALREADY_INITIALIZED"
        );
        require(
            address(_phase1) != address(0),
            "Treasury::initializePhase1: ZERO_ADDRESS"
        );
        require(
            _phase1.treasury() == address(this),
            "Treasury::initializePhase2: WRONG_TREASURY"
        );
        phase1 = _phase1;
        phase1.assignTreasury(address(this));
        flow.mint(_phase1.cap());
        emit InitializePhase(1);
    }

    function initializePhase2(ITreasuryPhase _phase2) external {
        require(
            _getPhase(issuanceToken) == Phase.One ||
                address(phase2) == address(0),
            "Treasury::initializePhase2: ALREADY_INITIALIZED"
        );
        require(
            address(_phase2) != address(0),
            "Treasury::initializePhase2: ZERO_ADDRESS"
        );
        require(
            msg.sender == phase1.deployer(),
            "Treasury::initializePhase2: UNAUTHORIZED"
        );
        require(
            _phase2.treasury() == address(this),
            "Treasury::initializePhase2: WRONG_TREASURY"
        );
        phase2 = _phase2;
        phase2.assignTreasury(address(this));
        flow.mint(_phase2.cap());
        emit InitializePhase(2);
    }

    function initializePhase3(ITreasuryPhase _phase3) external {
        require(
            _getPhase(issuanceToken) == Phase.Two,
            "Treasury::initializePhase3: ALREADY_INITIALIZED"
        );
        require(
            address(_phase3) != address(0),
            "Treasury::initializePhase3: ZERO_ADDRESS"
        );
        require(
            msg.sender == phase2.deployer(),
            "Treasury::initializePhase2: UNAUTHORIZED"
        );
        phase3 = _phase3;
        phase3.assignTreasury(address(this));
        emit InitializePhase(3);
    }

    function swap(
        IERC20 _from,
        uint256 _amount,
        IERC20 _to,
        uint256 _expectedSwappedAmount
    ) external override onlyController returns (uint256 _resultingAmount) {
        Phase _phase = _getPhase(_to);
        require(_phase != Phase.None, "Treasury::transform: BAD_STATE");
        if (_phase == Phase.One) {
            require(
                address(phase1) != address(0),
                "Treasury::transform: CONTRACT_MISSING"
            );
            _resultingAmount = phase1.swap(
                _from,
                _amount,
                issuanceToken,
                _amount.mul(PHASE_1_RATE)
            );
            withdrawableFunds[_from] = withdrawableFunds[_from].add(_amount);
        }
        if (_phase == Phase.Two) {
            require(
                address(phase2) != address(0),
                "Treasury::transform: CONTRACT_MISSING"
            );
            _resultingAmount = phase2.swap(
                _from,
                _amount,
                issuanceToken,
                _amount.mul(PHASE_2_RATE)
            );
            withdrawableFunds[_from] = withdrawableFunds[_from].add(_amount);
        }
        require(
            address(phase3) != address(0),
            "Treasury::transform: CONTRACT_MISSING"
        );
        _resultingAmount = phase3.swap(
            _from,
            _amount,
            _to,
            _expectedSwappedAmount
        );
        emit Swap(_from, _amount, _to, _resultingAmount);
    }

    function payout(
        address _receiver,
        IERC20 _token,
        uint256 _amount
    ) external override onlyController {
        _token.safeTransfer(_receiver, _amount);
    }

    function withdraw(
        address _to,
        IERC20 _token,
        uint256 _amount
    ) external override onlyController {
        require(
            withdrawableFunds[_token] >= _amount,
            "Treasury::withdrawFunds: INSUFFICIENT_FUNDS"
        );
        withdrawableFunds[_token] = withdrawableFunds[_token].sub(_amount);
        _token.safeTransfer(_to, _amount);
    }

    function transition(address _newTreasury, IERC20[] calldata _tokens)
        external
        override
        onlyController
    {
        flow.replaceTreasury(_newTreasury);
        IERC20(flow).safeTransfer(_newTreasury, flow.balanceOf(address(this)));
        for (uint256 i = 0; i < _tokens.length; i++) {
            _tokens[i].safeTransfer(
                _newTreasury,
                _tokens[i].balanceOf(address(this))
            );
        }
        emit Transition(_newTreasury);
    }

    function _getPhase(IERC20 _token) private returns (Phase) {
        if (address(phase1) == address(0)) return Phase.None;
        if (
            phase1.tokensIssued(_token) < phase1.cap() ||
            address(phase2) == address(0)
        ) return Phase.One;
        else if (
            phase1.tokensIssued(_token) < phase2.cap() ||
            address(phase3) == address(0)
        ) return Phase.Two;
        return Phase.Three;
    }
}
