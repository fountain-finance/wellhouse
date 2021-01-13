// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./interfaces/ITreasury.sol";

import "./Flow.sol";

contract Treasury is ITreasury {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    modifier onlyFountain {
        require(msg.sender == fountain, "Treasury: UNAUTHORIZED");
        _;
    }

    /// @notice The treasury behaves in different ways depending on the phase.
    /// @dev The phase is determined by the amount of surplus in the system.
    enum Phase {None, One, Two, Three}

    /// @notice The rate at which to issue FLOW for DAI in phase 1.
    uint8 public constant PHASE_1_RATE = 2;
    /// @notice The rate at which to issue FLOW for DAI in phase 2.
    uint8 public constant PHASE_2_RATE = 1;
    /// @notice The address of the FLOW ERC20 token.
    Flow public flow;
    /// @notice The contract managing Phase 1 token transformations.
    ITreasuryPhase public override phase1;
    /// @notice The contract managing Phase 2 token transformations.
    ITreasuryPhase public override phase2;
    /// @notice The contract managing Phase 3 token transformations.
    ITreasuryPhase public override phase3;
    /// @notice Amount of tokens from Phase 1 and Phase 2 that have yet to be withdrawn.
    uint256 public override withdrawableFunds;
    /// @notice The Fountain that this Treasury belongs to.
    address public override fountain;

    constructor(Flow _flow, address _fountain) public {
        fountain = _fountain;
        flow = _flow;
        withdrawableFunds = 0;
    }

    function initializePhase1(ITreasuryPhase _phase1) external {
        require(
            _getPhase() == Phase.None || address(phase1) == address(0),
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
    }

    function initializePhase2(ITreasuryPhase _phase2) external {
        require(
            _getPhase() == Phase.One || address(phase2) == address(0),
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
    }

    function initializePhase3(ITreasuryPhase _phase3) external {
        require(
            _getPhase() == Phase.Two,
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
    }

    function transform(
        uint256 _amount,
        IERC20 _token,
        uint256 _expectedConvertedAmount
    ) external override onlyFountain returns (uint256 _flowAmount) {
        Phase _phase = _getPhase();
        require(_phase != Phase.None, "Treasury::transform: BAD_STATE");
        if (_phase == Phase.One) {
            require(
                address(phase1) != address(0),
                "Treasury::transform: CONTRACT_MISSING"
            );
            _flowAmount = phase1.transform(
                _amount,
                _token,
                _amount.mul(PHASE_1_RATE)
            );
            withdrawableFunds = withdrawableFunds.add(_amount);
        }
        if (_phase == Phase.Two) {
            require(
                address(phase2) != address(0),
                "Treasury::transform: CONTRACT_MISSING"
            );
            _flowAmount = phase2.transform(
                _amount,
                _token,
                _amount.mul(PHASE_2_RATE)
            );
            withdrawableFunds = withdrawableFunds.add(_amount);
        }
        require(
            address(phase3) != address(0),
            "Treasury::transform: CONTRACT_MISSING"
        );
        _flowAmount = phase3.transform(
            _amount,
            _token,
            _expectedConvertedAmount
        );
        emit Transform(_token, _amount, _flowAmount);
    }

    function payout(
        address _receiver,
        IERC20 _token,
        uint256 _amount
    ) external override onlyFountain {
        _token.safeTransfer(_receiver, _amount);
    }

    function withdraw(
        address _to,
        IERC20 _token,
        uint256 _amount
    ) external override onlyFountain {
        require(
            withdrawableFunds >= _amount,
            "Treasury::withdrawFunds: INSUFFICIENT_FUNDS"
        );
        _token.safeTransfer(_to, _amount);
        withdrawableFunds = withdrawableFunds.sub(_amount);
    }

    function transition(address _newTreasury, IERC20[] calldata _tokens)
        external
        override
        onlyFountain
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

    function _getPhase() private returns (Phase) {
        if (address(phase1) == address(0)) return Phase.None;
        if (
            phase1.tokensIssued() < phase1.cap() ||
            address(phase2) == address(0)
        ) return Phase.One;
        else if (
            phase1.tokensIssued() < phase2.cap() ||
            address(phase3) == address(0)
        ) return Phase.Two;
        return Phase.Three;
    }
}
