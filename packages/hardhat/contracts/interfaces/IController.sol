// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "./IMpController.sol";
import "./ITicketStoreController.sol";

interface IController is IMpController, ITicketStoreController {
    function treasury() external returns (ITreasury);

    function getWantTokenAllowList() external returns (IERC20[] memory);

    function setTreasury(ITreasury _treasury) external;

    function setAdmin(address _admin) external;
}
