// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "./IMpController.sol";
import "./ITicketStoreController.sol";

interface IController is IMpController, ITicketStoreController {
    event WithdrawFunds(IERC20 token, uint256 amount);
    event SetTreasury(ITreasury treasury);
    event AppointTreasury(ITreasury newTreasury);

    function setTreasury(ITreasury _treasury) external;

    function appointTreasury(ITreasury _newTreasury) external;

    function withdrawFunds(uint256 _amount, IERC20 _token) external;
}
