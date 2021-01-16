// // SPDX-License-Identifier: MIT
// pragma solidity >=0.6.0 <0.8.0;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/math/SafeMath.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

// import "./interfaces/ITreasuryPhase.sol";

// contract Farm {
//     using SafeERC20 for IERC20;

//     // We need to keep track of how much each person has staked;
//     IERC20 public lpToken;
//     mapping(address => uint256) staked;

//     constructor(IERC20 _lpToken) public {
//         lpToken = _lpToken;
//     }

//     function stake(uint256 _amount) external {
//         require(_amount > 0, "Farm::stake: BAD_AMOUNT");
//         lpToken.safeTransferTo(msg.sender, address(this), _amount);
//         staked[msg.sender] = staked[msg.sender].add(_amount);
//     }

//     function unstake(uint256 _amount) external {
//         require(_amount < staked[msg.sender], "Farm::stake: BAD_AMOUNT");
//         lpToken.transferFrom(msg.sender, address(this), _amount);
//         staked[msg.sender] = staked[msg.sender].sub(_amount);
//     }
// }

// contract TreasuryPhase2 is ITreasuryPhase {
//     using SafeMath for uint256;
//     using SafeERC20 for IERC20;

//     /// @notice The max amount of tokens to issue.
//     uint256 public constant override cap = 10000000E18;

//     /// @notice The address that deployed this contract.
//     address public override deployer;

//     /// @notice Amount of each token issued so far.
//     mapping(IERC20 => uint256) public override tokensIssued;

//     /// @notice The address where funds are managed
//     address public override treasury;

//     constructor() public {
//         deployer = msg.sender;
//     }

//     /**
//       @notice Swap the specified amount into tokens.
//       @param _from The token being swapped from.
//       @param _amount The amount of tokens to use for issuing.
//       @param _to The token being swapped to.
//       @param _expectedTransformAmount The amount of tokens expected in exchange.
//       @return _swapped The amount of tokens issued.
//     */
//     function swap(
//         IERC20 _from,
//         uint256 _amount,
//         IERC20 _to,
//         uint256 _expectedSwapAmount
//     ) external override returns (uint256) {
//         require(
//             msg.sender == treasury,
//             "TreasuryPhase1::swap: UNAUTHORIZED"
//         );
//         require(
//             _validIssuance(_expectedTransformAmount, _to),
//             "TreasuryPhase1::swap: INVALID"
//         );
//         tokensIssued[_to] = tokensIssued[_to].add(_expectedTransformAmount);

//         // track _expectedTransformAmount, and provide a transaction where this amount can be
//         // converted into FLOW and distributed to the farm.

//         // Mint sqrt(_expectedTransformAmount) and give to the farm.
//         _mintLpShares(_);
//         _distributeLpShares(_);

//         return _expectedTransformAmount;
//     }

//     function assignTreasury(address _treasury) external override {
//         require(
//             treasury == address(0),
//             "TreasuryPhase1::_assignTreasury: ALREADY_ASSIGNED"
//         );
//         treasury = _treasury;
//     }

//     function _validIssuance(uint256 _amount, IERC20 _token)
//         private
//         view
//         returns (bool)
//     {
//         return _amount > 0 && tokensIssued[_token].add(_amount) <= cap;
//     }
// }
