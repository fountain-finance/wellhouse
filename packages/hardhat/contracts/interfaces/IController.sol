// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "./IMpController.sol";
import "./ITicketStandController.sol";

interface IController is IMpController, ITicketStandController {
    // function appointTreasury(ITreasury _newTreasury) external;
    // function withdrawFunds(uint256 _amount, IERC20 _token) external;
}
