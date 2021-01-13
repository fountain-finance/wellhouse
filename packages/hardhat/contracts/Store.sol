// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "./libraries/MoneyPool.sol";
import "./aux/Ticket.sol";

contract Store {
    using SafeMath for uint256;
    using MoneyPool for MoneyPool.Data;

    address public controller;

    modifier onlyController {
        require(msg.sender == controller, "Get: UNAUTHORIZED");
        _;
    }

    /// @notice a big number to base ticket issuance off of.
    uint256 public constant BASE_MP_WEIGHT = 100000000000E18;

    // @notice The official record of all Money pools ever created
    mapping(uint256 => MoneyPool.Data) public mp;
    /// @notice The tickets handed out to Money pool sustainers. Each owner has their own set of tickets.
    mapping(address => Ticket) public ticket;
    /// @notice The current cumulative amount redistributable from each owner's Money pools.
    mapping(address => uint256) public redeemable;
    /// @notice The latest Money pool for each owner address
    mapping(address => uint256) public latestMpId;
    /// @notice The total number of Money pools created, which is used for issuing Money pool IDs.
    /// @dev Money pools should have a ID > 0.
    uint256 public mpCount = 0;

    // --- external views --- //

    /**  
        @notice The Money pool with the given ID.
        @param _mpId The ID of the Money pool to get the properties of.
        @return _mp The Money pool.
    */
    function getMp(uint256 _mpId)
        external
        view
        returns (MoneyPool.Data memory)
    {
        require(_mpId > 0 && _mpId <= mpCount, "Fountain::getMp: NOT_FOUND");
        return mp[_mpId];
    }

    /**
        @notice The Money pool that's next up for an owner and not currently accepting payments.
        @param _owner The owner of the Money pool being looked for.
        @return _mp The Money pool.
    */
    function getQueuedMp(address _owner)
        external
        view
        returns (MoneyPool.Data memory)
    {
        MoneyPool.Data memory _sMp = _standbyMp(_owner);
        MoneyPool.Data memory _aMp = _activeMp(_owner);
        if (_sMp.id > 0 && _aMp.id > 0) return _sMp;
        require(_aMp.id > 0, "Fountain::getQueuedMp: NOT_FOUND");
        return _aMp._nextUp();
    }

    /**
        @notice The Money pool that would be currently accepting sustainments.
        @param _owner The owner of the money pool being looked for.
        @return _mp The Money pool.
    */
    function getCurrentMp(address _owner)
        external
        view
        returns (MoneyPool.Data memory _mp)
    {
        require(latestMpId[_owner] > 0, "Fountain::getCurrentMp: NOT_FOUND");
        _mp = _activeMp(_owner);
        if (_mp.id > 0) return _mp;
        _mp = _standbyMp(_owner);
        if (_mp.id > 0) return _mp;
        _mp = mp[latestMpId[_owner]];
        return _mp._nextUp();
    }

    /**
        @notice The amount left to be withdrawn by the Money pool's owner.
        @param _mpId The ID of the Money pool to get the available sustainment from.
        @return amount The amount.
    */
    function getTappableAmount(uint256 _mpId) external view returns (uint256) {
        require(
            _mpId > 0 && _mpId <= mpCount,
            "Fountain::getTappableAmount:: NOT_FOUND"
        );
        return mp[_mpId]._tappableAmount();
    }

    /** 
        @notice The amount of redistribution that can be claimed by the given address in the Fountain ecosystem.
        @dev This function runs the same routine as _redistributeAmount to determine the summed amount.
        Look there for more documentation.
        @param _beneficiary The address to get an amount for.
        @param _owner The owner of the Money pools to get an amount for.
        @return _amount The amount.
    */
    function getRedeemableAmount(address _beneficiary, address _owner)
        external
        view
        returns (uint256)
    {
        return _redeemableAmount(_beneficiary, _owner);
    }

    // --- external transactions --- //

    /** 
        @notice Saves a Money pool to storage.
        @param _mp The Money pool to save.
    */
    function saveMp(MoneyPool.Data memory _mp) external onlyController {
        mp[_mp.id] = _mp;
    }

    /** 
        @notice Saves a Ticket to storage relative.
        @param _owner The owner of the Ticket.
        @param _ticket The Ticket to assign to the owner.
    */
    function assignTicketOwner(address _owner, Ticket _ticket)
        external
        onlyController
    {
        ticket[_owner] = _ticket;
    }

    function addRedeemable(address _owner, uint256 _amount)
        external
        onlyController
    {
        redeemable[_owner] = redeemable[_owner].add(_amount);
    }

    function subtractRedeemable(address _owner, uint256 _amount)
        external
        onlyController
    {
        redeemable[_owner] = redeemable[_owner].sub(_amount);
    }

    /** 
        @notice Returns the active Money pool for this owner if it exists, otherwise activating one appropriately.
        @param _owner The address who owns the Money pool to look for.
        @return _mp The resulting Money pool.
    */
    function ensureActiveMp(address _owner)
        external
        returns (MoneyPool.Data memory _mp)
    {
        // Check if there is an active moneyPool
        _mp = _activeMp(_owner);
        if (_mp.id > 0) return _mp;
        // No active moneyPool found, check if there is a standby moneyPool
        _mp = _standbyMp(_owner);
        if (_mp.id > 0) return _mp;
        // No upcoming moneyPool found, clone the latest moneyPool
        _mp = mp[latestMpId[_owner]];
        require(_mp.id > 0, "Fountain::_mpToSustain: NOT_FOUND");
        // Use a start date that's a multiple of the duration.
        // This creates the effect that there have been scheduled Money pools ever since the `latest`, even if `latest` is a long time in the past.
        MoneyPool.Data memory _newMp =
            _initMp(_mp.owner, _mp._determineNextStart(), _mp._derivedWeight());
        _newMp._basedOn(_mp);
        return _newMp;
    }

    /** 
        @notice Returns the standby Money pool for this owner if it exists, otherwise putting one in standby appropriately.
        @param _owner The address who owns the Money pool to look for.
        @return _mp The resulting Money pool.
    */
    function ensureStandbyMp(address _owner)
        external
        returns (MoneyPool.Data memory _mp)
    {
        // Cannot update active moneyPool, check if there is a standby moneyPool
        _mp = _standbyMp(_owner);
        if (_mp.id > 0) return _mp;
        _mp = mp[latestMpId[_owner]];
        // If there's an active Money pool, its end time should correspond to the start time of the new Money pool.
        MoneyPool.Data memory _aMp = _activeMp(_owner);
        MoneyPool.Data memory _newMp =
            _aMp.id > 0
                ? _initMp(
                    _owner,
                    _aMp.start.add(_aMp.duration),
                    _aMp._derivedWeight()
                )
                : _initMp(_owner, block.timestamp, BASE_MP_WEIGHT);
        if (_mp.id > 0) _newMp._basedOn(_mp);
        return _newMp;
    }

    // --- private transactions --- //

    /** 
        @notice Initializes a Money pool to be sustained for the sending address.
        @param _owner The owner of the Money pool being initialized.
        @param _start The start time for the new Money pool.
        @param _weight The weight for the new Money pool.
        @return _newMp The initialized Money pool.
    */
    function _initMp(
        address _owner,
        uint256 _start,
        uint256 _weight
    ) private returns (MoneyPool.Data storage _newMp) {
        mpCount++;
        _newMp = mp[mpCount];
        _newMp._init(_owner, _start, mpCount, latestMpId[_owner], _weight);
        latestMpId[_owner] = mpCount;
    }

    /** 
        @notice An owner's edittable Money pool.
        @param _owner The owner of the money pool being looked for.
        @return _mp The standby Money pool.
    */
    function _standbyMp(address _owner)
        private
        view
        returns (MoneyPool.Data memory _mp)
    {
        _mp = mp[latestMpId[_owner]];
        if (_mp.id == 0) return mp[0];
        // There is no upcoming Money pool if the latest Money pool is not upcoming
        if (_mp._state() != MoneyPool.State.Standby) return mp[0];
    }

    /** 
        @notice The currently active Money pool for an owner.
        @param _owner The owner of the money pool being looked for.
        @return _mp The active Money pool.
    */
    function _activeMp(address _owner)
        public
        view
        returns (MoneyPool.Data memory _mp)
    {
        _mp = mp[latestMpId[_owner]];
        if (_mp.id == 0) return mp[0];
        // An Active moneyPool must be either the latest moneyPool or the
        // moneyPool immediately before it.
        if (_mp._state() == MoneyPool.State.Active) return _mp;
        _mp = mp[_mp.previous];
        if (_mp.id == 0 || _mp._state() != MoneyPool.State.Active) return mp[0];
    }

    // --- private views --- //

    /** 
        @notice The amount that the provided beneficiary has access to from the provided owner's Money pools.
        @param _beneficiary The account to check the balance of.
        @param _owner The owner of the Money pools being considered.
        @return _amount The amount that is redistributable.
    */
    function _redeemableAmount(address _beneficiary, address _owner)
        private
        view
        returns (uint256)
    {
        Ticket _ticket = ticket[_owner];
        uint256 _currentBalance = _ticket.balanceOf(_beneficiary);
        return
            redeemable[_owner].mul(_currentBalance).div(_ticket.totalSupply());
    }
}
