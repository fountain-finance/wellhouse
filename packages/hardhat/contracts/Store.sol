// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./libraries/MoneyPool.sol";

contract Ticket is ERC20, AccessControl {
    modifier onlyAdmin {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        _;
    }

    constructor(string memory _name, string memory _symbol)
        public
        ERC20(_name, _symbol)
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address _account, uint256 _amount) external onlyAdmin {
        return _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external onlyAdmin {
        return _burn(_account, _amount);
    }
}

contract Store {
    using SafeMath for uint256;
    using MoneyPool for MoneyPool.Data;

    modifier onlyController {
        require(msg.sender == controller, "Store: UNAUTHORIZED");
        _;
    }

    // --- private properties --- //

    // The official record of all Money pools ever created.
    // TODO Making this public causes a Stack Too Deep error for some reason.
    mapping(uint256 => MoneyPool.Data) private mp;

    // --- public properties --- //

    /// @notice a big number to base ticket issuance off of.
    uint256 public constant MP_BASE_WEIGHT = 1000000000E18;

    /// @notice The address controlling this Store.
    address public controller;
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
        Ticket _ticket = ticket[_owner];
        uint256 _currentBalance = _ticket.balanceOf(_beneficiary);
        return
            redeemable[_owner].mul(_currentBalance).div(_ticket.totalSupply());
    }

    // --- external transactions --- //

    /** 
        @notice Configures the description of a Money pool.
        @param _mpId The ID of the Money pool to configure.
        @param _title The title of the Money pool.
        @param _link A link to associate with the Money pool.
    */
    function configureMpDescription(
        uint256 _mpId,
        string calldata _title,
        string calldata _link
    ) external onlyController returns (MoneyPool.Data memory) {
        MoneyPool.Data storage _mp = mp[_mpId];
        _mp.title = _title;
        _mp.link = _link;
        return _mp;
    }

    /** 
        @notice Configures the core properties of a Money pool.
        @param _mpId The ID of the Money pool to configure.
        @param _target The sustainability target to set.
        @param _duration The duration to set, measured in seconds.
        @param _want The token that the Money pool wants.
        @param _start The new start time.
    */
    function configureMpFundingSchedule(
        uint256 _mpId,
        uint256 _target,
        uint256 _duration,
        IERC20 _want,
        uint256 _start
    ) external onlyController returns (MoneyPool.Data memory) {
        MoneyPool.Data storage _mp = mp[_mpId];
        _mp.target = _target;
        _mp.duration = _duration;
        _mp.want = _want;
        _mp.start = _start;
        return _mp;
    }

    /** 
        @notice Configures the properties of a Money pool that affect redistribution.
        @param _mpId The ID of the Money pool to configure.
        @param _bias The new bias.
        @param _o The new owner share.
        @param _b The new beneficiary share.
        @param _bAddress The new beneficiary address.
    */
    function configureMpRedistribution(
        uint256 _mpId,
        uint256 _bias,
        uint256 _o,
        uint256 _b,
        address _bAddress
    ) external onlyController returns (MoneyPool.Data memory) {
        MoneyPool.Data storage _mp = mp[_mpId];
        _mp.bias = _bias;
        _mp.o = _o;
        _mp.b = _b;
        _mp.bAddress = _bAddress;
        return _mp;
    }

    /** 
        @notice Contribute a specified amount to the sustainability of a Money pool.
        @param _mpId The ID of the Money pool to sustain.
        @param _amount Incrmented amount of sustainment.
        @return _surplus The amount of surplus in the Money pool after adding.
    */
    function addToMp(uint256 _mpId, uint256 _amount)
        external
        onlyController
        returns (uint256)
    {
        MoneyPool.Data storage _mp = mp[_mpId];
        // Increment the total amount contributed to the sustainment of the Money pool.
        _mp.total = _mp.total.add(_amount);
        return _mp.total > _mp.target ? _mp.total.sub(_mp.target) : 0;
    }

    /** 
        @dev Increase the amount that has been tapped by the Money pool's owner.
        @param _mpId The ID of the Money pool to tap.
        @param _amount The amount to tap.
    */
    function tapFromMp(uint256 _mpId, uint256 _amount) external onlyController {
        MoneyPool.Data storage _mp = mp[_mpId];
        _mp.tapped = _mp.tapped.add(_amount);
    }

    /** 
        @notice Marks a Money pool as having minted all of its reserves.
        @param _mpId The ID of the Money pool to sustain.
    */
    function markMpReservesAsMinted(uint256 _mpId) external onlyController {
        mp[_mpId].hasMintedReserves = true;
    }

    /**
        @notice Saves a Ticket to storage for the provided owner.
        @param _owner The owner of the Ticket.
        @param _ticket The Ticket to assign to the owner.
    */
    function assignTicket(address _owner, Ticket _ticket)
        external
        onlyController
    {
        ticket[_owner] = _ticket;
    }

    /**
        @notice Adds an amount to the total that can be redeemable for the given owner's Ticket holders.
        @param _owner The owner of the Ticket.
        @param _amount The amount to increment.
    */
    function addRedeemable(address _owner, uint256 _amount)
        external
        onlyController
    {
        redeemable[_owner] = redeemable[_owner].add(_amount);
    }

    /**
        @notice Subtracts an amount to the total that can be redeemable for the given owner's Ticket holders.
        @param _owner The owner of the Ticket.
        @param _amount The amount to decrement.
    */
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
    function activeMp(address _owner)
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
