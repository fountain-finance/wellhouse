// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./Flow.sol";
import "./Phase1.sol";
import "./interfaces/IPhase.sol";
import "./libraries/Math.sol";

contract OverflowTreasury {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice The treasury behaves in different ways depending on the phase.
    /// @dev The phase is determined by the amount of surplus in the system.
    enum Phase {NONE, ONE, TWO, THREE}

    /// @notice The amount of FLOW tokens issued in Phase 1 to transition to Phase 2.
    uint256 public constant PHASE_1_CAP = 700000E18;

    /// @notice The amount of FLOW tokens issued in Phase 2 to transition to Phase 3.
    uint256 public constant PHASE_2_CAP = 93000000E18;

    /// @notice The rate at which to issue FLOW for DAI in phase 1.
    uint8 public constant PHASE_1_RATE = 2;

    /// @notice The rate at which to issue FLOW for DAI in phase 2.
    uint8 public constant PHASE_2_RATE = 1;

    /// @notice The address of the FLOW ERC20 token.
    Flow public flow;

    /// @notice The contract managing Phase 1 token transformations.
    IPhase public phase1;

    /// @notice The contract managing Phase 2 token transformations.
    IPhase public phase2;

    /// @notice The contract managing Phase 3 token transformations.
    IPhase public phase3;

    /**
     * Event for token transforming
     * @param token The token to transform.
     * @param value The amount tokens to transform.
     * @param amount The amount of FLOW tokens resulting from the transformation.
     */
    event Transform(IERC20 token, uint256 value, uint256 amount);

    constructor() public {
        flow = new Flow();
    }

    function initializePhase1(IPhase _phase1) external {
        require(
            _getPhase() == Phase.NONE || address(phase1) == address(0),
            "OverflowTreasury::initializePhase1: ALREADY_INITIALIZED"
        );
        require(
            address(_phase1) != address(0),
            "OverflowTreasury::initializePhase1: ZERO_ADDRESS"
        );
        phase1 = _phase1;
        flow.mint(PHASE_1_CAP);
    }

    function initializePhase2(IPhase _phase2) external {
        require(
            _getPhase() == Phase.ONE || address(phase2) == address(0),
            "OverflowTreasury::initializePhase2: ALREADY_INITIALIZED"
        );
        require(
            address(_phase2) != address(0),
            "OverflowTreasury::initializePhase2: ZERO_ADDRESS"
        );
        phase2 = _phase2;
        flow.mint(PHASE_2_CAP);
    }

    function initializePhase3(IPhase _phase3) external {
        require(
            _getPhase() == Phase.TWO,
            "OverflowTreasury::initializePhase3: ALREADY_INITIALIZED"
        );
        require(
            address(_phase3) != address(0),
            "OverflowTreasury::initializePhase3: ZERO_ADDRESS"
        );
        phase3 = _phase3;
    }

    function transform(
        uint256 _amount,
        IERC20 _token,
        uint256 _expectedConvertedAmount
    ) public returns (uint256 _flowAmount) {
        Phase _phase = _getPhase();
        require(_phase != Phase.None, "OverflowTreasury::transform: BAD_STATE");

        if (_phase == Phase.ONE) {
            require(
                address(phase1) != address(0),
                "OverflowTreasury::transform: CONTRACT_MISSING"
            );
            _flowAmount = phase1.transform(
                _amount,
                _token,
                _amount.mul(PHASE_1_RATE)
            );
        }
        if (_phase == Phase.TWO) {
            require(
                address(phase2) != address(0),
                "OverflowTreasury::transform: CONTRACT_MISSING"
            );
            _flowAmount = phase2.transform(
                _amount,
                _token,
                _amount.mul(PHASE_2_RATE)
            );
        }
        require(
            address(phase3) != address(0),
            "OverflowTreasury::transform: CONTRACT_MISSING"
        );
        _flowAmount = phase3.transform(
            _amount,
            _token,
            _expectedConvertedAmount
        );

        emit Transform(_token, _amount, _flowAmount);
    }

    function _getPhase() private returns (Phase) {
        if (address(phase1) == address(0)) return Phase.NONE;
        if (
            phase1.tokensIssued() < PHASE_1_CAP || address(phase2) == address(0)
        ) return Phase.ONE;
        else if (
            phase1.tokensIssued() < PHASE_2_CAP || address(phase3) == address(0)
        ) return Phase.TWO;
        return Phase.THREE;
    }
}
