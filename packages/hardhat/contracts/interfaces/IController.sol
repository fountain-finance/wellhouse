// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "./ITicketStore.sol";
import "./IMpStore.sol";
import "./IMpController.sol";
import "./ITicketStoreController.sol";

interface IController is IMpController, ITicketStoreController {
    function mpStore() external returns (IMpStore);

    function ticketStore() external returns (ITicketStore);

    function treasury() external returns (ITreasury);

    function setTreasury(ITreasury _treasury) external;

    function setAdmin(address _admin) external;
}
