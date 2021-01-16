// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITreasuryPhase {
    function deployer() external returns (address);

    function cap() external returns (uint256);

    function tokensIssued(IERC20 _token) external returns (uint256);

    function treasury() external returns (address);

    function swap(
        IERC20 _from,
        uint256 _amount,
        IERC20 _to,
        uint256 _expectedSwappedAmount
    ) external returns (uint256 _swapped);

    function assignTreasury(address _treasury) external;
}
