// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./libraries/MoneyPool.sol";
import "./interfaces/ITicketStand.sol";

contract Ticket is ERC20, AccessControl {
    modifier onlyAdmin {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        _;
    }

    address public owner;
    ITicketStand public stand;
    IERC20 public redeemableFor;

    constructor(
        string memory _name,
        string memory _symbol,
        address _owner,
        ITicketStand _stand,
        IERC20 _redeemableFor
    ) public ERC20(_name, _symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        stand = _stand;
        owner = _owner;
        redeemableFor = _redeemableFor;
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
    mapping(uint256 => MoneyPool.Data) private mp;

    // --- public properties --- //

    /// @notice a big number to base ticket issuance off of.
    uint256 public constant MP_BASE_WEIGHT = 1000000000E18;

    /// @notice The address controlling this Store.
    address public controller;
    /// @notice The Tickets handed out to Money pool sustainers. Each owner has their own Ticket contract.
    mapping(address => Ticket) public ticket;
    /// @notice The current cumulative amount of redeemable tokens redistributable to each owner's Ticket holders.
    mapping(address => mapping(IERC20 => uint256)) public redeemable;
    /// @notice The latest Money pool for each owner address
    mapping(address => uint256) public latestMpId;
    /// @notice The total number of Money pools created, which is used for issuing Money pool IDs.
    /// @dev Money pools should have a ID > 0.
    uint256 public mpCount = 0;
    /// @notice The amount of each token that is transformable into another token for each owner
    mapping(address => mapping(IERC20 => mapping(IERC20 => uint256)))
        public transformable;
    /// @notice Tracks the kinds of tokens an owner has accepted relative to their tickets' redeemable token.
    mapping(address => mapping(IERC20 => mapping(IERC20 => bool)))
        public acceptedTokenTracker;
    /// @notice The kinds of tokens an owner has accepted relative to their tickets' redeemable token.
    mapping(address => mapping(IERC20 => IERC20[])) public acceptedTokens;

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
        @notice The amount of redistribution that can be claimed by the given address.
        @dev This function runs the same routine as _redistributeAmount to determine the summed amount.
        Look there for more documentation.
        @param _beneficiary The address to get an amount for.
        @param _owner The owner of the Tickets to get an amount for.
        @param _token The token to get an amount for.
        @return _amount The amount.
    */
    function getRedeemableAmount(
        address _beneficiary,
        address _owner,
        IERC20 _token
    ) external view returns (uint256) {
        Ticket _ticket = ticket[_owner];
        uint256 _currentBalance = _ticket.balanceOf(_beneficiary);
        return
            redeemable[_owner][_token].mul(_currentBalance).div(
                _ticket.totalSupply()
            );
    }

    /**
        @notice The value that a Ticket can be redeemed for.
        @param _owner The owner of the Ticket to get a value for.
        @param _token The reward token of the Ticket to get a value for.
        @return _value The value.
    */
    function getCurrentTicketValue(address _owner, IERC20 _token)
        external
        view
        returns (uint256)
    {
        Ticket _ticket = ticket[_owner];
        return redeemable[_owner][_token].div(_ticket.totalSupply());
    }

    /**
        @notice All tokens that this owner has accepted.
        @param _owner The owner to get accepted tokens for.
        @param _token The token redeemable for the accepted tokens.
        @return _tokens An array of tokens.
    */
    function getAcceptedTokens(address _owner, IERC20 _token)
        external
        view
        returns (IERC20[] memory)
    {
        return acceptedTokens[_owner][_token];
    }

    // --- external transactions --- //

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
        @param _token The token to increment.
        @param _amount The amount to increment.
    */
    function addRedeemable(
        address _owner,
        IERC20 _token,
        uint256 _amount
    ) external onlyController {
        redeemable[_owner][_token] = redeemable[_owner][_token].add(_amount);
    }

    /**
        @notice Subtracts an amount to the total that can be redeemable for the given owner's Ticket holders.
        @param _owner The owner of the Ticket.
        @param _token The token to decrement.
        @param _amount The amount to decrement.
    */
    function subtractRedeemable(
        address _owner,
        IERC20 _token,
        uint256 _amount
    ) external onlyController {
        redeemable[_owner][_token] = redeemable[_owner][_token].sub(_amount);
    }

    /**
        @notice Adds an amount that can be transformable from one token to another.
        @param _owner The owner of the Tickets responsible for the funds.
        @param _from The original token.
        @param _amount The amount of token1 to make transformable.
        @param _to The token to transform into.
    */
    function addTransformable(
        address _owner,
        IERC20 _from,
        uint256 _amount,
        IERC20 _to
    ) external onlyController {
        transformable[_owner][_from][_to] = transformable[_owner][_from][_to]
            .add(_amount);
    }

    /**
        @notice Subtracts the amount that can be transformable from one token to another.
        @param _owner The owner of the Tickets responsible for the funds.
        @param _from The original token.
        @param _amount The amount of token1 to make transformable.
        @param _to The token to transform into.
    */
    function subtractTransformable(
        address _owner,
        IERC20 _from,
        uint256 _amount,
        IERC20 _to
    ) external onlyController {
        transformable[_owner][_from][_to] = transformable[_owner][_from][_to]
            .sub(_amount);
    }

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
    ) external onlyController {
        if (!acceptedTokenTracker[_owner][_redeemableToken][_token]) {
            acceptedTokens[_owner][_redeemableToken].push(_token);
            acceptedTokenTracker[_owner][_redeemableToken][_token] = true;
        }
    }

    /**
        @notice Cleans the tracking array for an owner and a redeemable token.
        @dev This never needs to get called, it's here precautionarily. 
        @param _owner The owner of the Tickets responsible for the funds.
        @param _token The redeemable token to clean accepted tokens for.
    */
    function cleanTrackedAcceptedTokens(address _owner, IERC20 _token)
        external
    {
        IERC20[] memory currentAcceptedTokens = acceptedTokens[_owner][_token];
        //Clear array
        delete acceptedTokens[_owner][_token];
        MoneyPool.Data memory _sMp = _standbyMp(_owner);
        MoneyPool.Data memory _aMp = _activeMp(_owner);
        for (uint256 i = 0; i < currentAcceptedTokens.length; i++) {
            IERC20 _acceptedToken = currentAcceptedTokens[i];
            if (
                _aMp.want == _token ||
                _sMp.want == _token ||
                transformable[_owner][_acceptedToken][_token] > 0
            ) acceptedTokens[_owner][_token].push(_acceptedToken);
        }
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
    function saveMp(MoneyPool.Data memory _mp) public onlyController {
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
