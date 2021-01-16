// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./../libraries/MoneyPool.sol";

contract MpStore is AccessControl {
    using SafeMath for uint256;
    using MoneyPool for MoneyPool.Data;

    modifier onlyAdmin {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        _;
    }

    // --- private properties --- //

    // The official record of all Money pools ever created.
    mapping(uint256 => MoneyPool.Data) private mp;

    // Tracks the kinds of tokens an owner has wanted relative to their tickets' redeemable token.
    mapping(address => mapping(IERC20 => mapping(IERC20 => bool)))
        private wantedTokenTracker;

    // The kinds of tokens an owner has accepted relative to their tickets' redeemable token.
    mapping(address => mapping(IERC20 => IERC20[])) private wantedTokens;

    // --- public properties --- //

    /// @notice a big number to base ticket issuance off of.
    uint256 public constant MP_BASE_WEIGHT = 1000000000E18;

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
        require(_mpId > 0 && _mpId <= mpCount, "Store::getMp: NOT_FOUND");
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
        require(_aMp.id > 0, "Store::getQueuedMp: NOT_FOUND");
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
        require(latestMpId[_owner] > 0, "Store::getCurrentMp: NOT_FOUND");
        _mp = _activeMp(_owner);
        if (_mp.id > 0) return _mp;
        _mp = _standbyMp(_owner);
        if (_mp.id > 0) return _mp;
        _mp = mp[latestMpId[_owner]];
        return _mp._nextUp();
    }

    /**
        @notice The Money pool in the Standby state for the owner.
        @param _owner The owner of the money pool being looked for.
        @return _mp The Money pool.
    */
    function getStandbyMp(address _owner)
        external
        view
        returns (MoneyPool.Data memory _mp)
    {
        return _standbyMp(_owner);
    }

    /**
        @notice The Money pool in the Active state for the owner.
        @param _owner The owner of the money pool being looked for.
        @return _mp The Money pool.
    */
    function getActiveMp(address _owner)
        external
        view
        returns (MoneyPool.Data memory _mp)
    {
        return _activeMp(_owner);
    }

    /**
        @notice The amount left to be withdrawn by the Money pool's owner.
        @param _mpId The ID of the Money pool to get the available sustainment from.
        @return amount The amount.
    */
    function getTappableAmount(uint256 _mpId) external view returns (uint256) {
        require(
            _mpId > 0 && _mpId <= mpCount,
            "Store::getTappableAmount:: NOT_FOUND"
        );
        return mp[_mpId]._tappableAmount();
    }

    /**
        @notice All tokens that this owner has accepted.
        @param _owner The owner to get wanted tokens for.
        @param _rewardToken The token rewarded for the wanted tokens.
        @return _tokens An array of tokens.
    */
    function getWantedTokens(address _owner, IERC20 _rewardToken)
        external
        view
        returns (IERC20[] memory)
    {
        return wantedTokens[_owner][_rewardToken];
    }

    constructor() public {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // --- external transactions --- //

    /**
        @notice Tracks the kinds of tokens the specified owner has accepted historically.
        @param _owner The owner associate the token with.
        @param _redeemableToken The token that the tracked tokens can be redeemed for.
        @param _token The token to track.
    */
    function trackAcceptedToken(
        address _owner,
        IERC20 _redeemableToken,
        IERC20 _token
    ) external onlyAdmin {
        if (!wantedTokenTracker[_owner][_redeemableToken][_token]) {
            wantedTokens[_owner][_redeemableToken].push(_token);
            wantedTokenTracker[_owner][_redeemableToken][_token] = true;
        }
    }

    /**
        @notice Cleans the tracking array for an owner and a redeemable token.
        @dev This never needs to get called, it's here precautionarily.
        @param _owner The owner of the Tickets responsible for the funds.
        @param _token The tokens to clean accepted tokens for.
    */
    function clearWantedTokens(address _owner, IERC20 _token)
        external
        onlyAdmin
    {
        delete wantedTokens[_owner][_token];
    }

    /**
        @notice Returns the active Money pool for this owner if it exists, otherwise activating one appropriately.
        @param _owner The address who owns the Money pool to look for.
        @return _mp The resulting Money pool.
    */
    function activeMp(address _owner)
        external
        onlyAdmin
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
        require(_mp.id > 0, "Store::_mpToSustain: NOT_FOUND");
        // Use a start date that's a multiple of the duration.
        // This creates the effect that there have been scheduled Money pools ever since the `latest`, even if `latest` is a long time in the past.
        MoneyPool.Data storage _newMp =
            _initMp(_mp.owner, _mp._determineNextStart(), _mp._derivedWeight());
        _newMp._basedOn(_mp);
        return _newMp;
    }

    /**
        @notice Returns the standby Money pool for this owner if it exists, otherwise putting one in standby appropriately.
        @param _owner The address who owns the Money pool to look for.
        @return _mp The resulting Money pool.
    */
    function standbyMp(address _owner)
        external
        onlyAdmin
        returns (MoneyPool.Data memory _mp)
    {
        // Cannot update active moneyPool, check if there is a standby moneyPool
        _mp = _standbyMp(_owner);
        if (_mp.id > 0) return _mp;
        _mp = mp[latestMpId[_owner]];
        // If there's an active Money pool, its end time should correspond to the start time of the new Money pool.
        MoneyPool.Data memory _aMp = _activeMp(_owner);
        MoneyPool.Data storage _newMp =
            _aMp.id > 0
                ? _initMp(
                    _owner,
                    _aMp.start.add(_aMp.duration),
                    _aMp._derivedWeight()
                )
                : _initMp(_owner, block.timestamp, MP_BASE_WEIGHT);
        if (_mp.id > 0) _newMp._basedOn(_mp);
        return _newMp;
    }

    // --- public transactions --- //

    /** 
        @notice Saves a Money pool.
        @param _mp The Money pool to save.
    */
    function saveMp(MoneyPool.Data memory _mp) public onlyAdmin {
        mp[_mp.id] = _mp;
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
        _newMp.id = mpCount;
        _newMp.owner = _owner;
        _newMp.start = _start;
        _newMp.previous = latestMpId[_owner];
        _newMp.weight = _weight;
        _newMp.total = 0;
        _newMp.tapped = 0;
        _newMp.hasMintedReserves = false;
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
}