// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./ITreasuryPhase.sol";

interface ITreasury {
    function phase1() external returns (ITreasuryPhase);

    function phase2() external returns (ITreasuryPhase);

    function phase3() external returns (ITreasuryPhase);

    function withdrawableFunds(IERC20 _token) external returns (uint256);

    function fountain() external returns (address);

    event Transform(
        IERC20 from,
        uint256 amount,
        IERC20 to,
        uint256 resultingAmount
    );

    event Transition(address newTreasury);

    event InitializePhase(uint8 number);

    function transform(
        IERC20 _from,
        uint256 _amount,
        IERC20 _to,
        uint256 _expectedConvertedAmount
    ) external returns (uint256 _converted);

    function payout(
        address _receiver,
        IERC20 _token,
        uint256 _amount
    ) external;

    function transition(address _newTreasury, IERC20[] calldata _tokens)
        external;

    function withdraw(
        address _to,
        IERC20 _token,
        uint256 _amount
    ) external;
}
