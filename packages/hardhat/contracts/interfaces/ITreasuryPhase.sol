// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITreasuryPhase {
    /// @notice Amount of tokens issued.
    function tokensIssued() external returns (uint256);

    /// @notice The treasury controller's address.
    function treasuryController() external returns (address);

    function transform(
        uint256 _amount,
        IERC20 _token,
        uint256 _expectedConvertedAmount
    ) external returns (uint256 _converted);
}
