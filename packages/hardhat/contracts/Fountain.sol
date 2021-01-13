// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./libraries/MoneyPool.sol";
import "./interfaces/IFountain.sol";
import "./aux/Ticket.sol";

/**

@title Fountain

@notice
Create a Money pool (MP) that'll be used to sustain your project, and specify what its sustainability target is.
Maybe your project is providing a service or public good, maybe it's being a YouTuber, engineer, or artist -- or anything else.
Anyone with your address can help sustain your project, and once you're sustainable any additional contributions are redistributed back your sustainers.

Each Money pool is like a tier of the fountain, and the predefined cost to pursue the project is like the bounds of that tier's pool.

@dev
An address can only be associated with one active Money pool at a time, as well as a mutable one queued up for when the active Money pool expires.
If a Money pool expires without one queued, the current one will be cloned and sustainments at that time will be allocated to it.
It's impossible for a Money pool's sustainability or duration to be changed once there has been a sustainment made to it.
Any attempts to do so will just create/update the message sender's queued MP.

You can collect funds of yours from the sustainers pool (where Money pool surplus is distributed) or from the sustainability pool (where Money pool sustainments are kept) at anytime.

Future versions will introduce Money pool dependencies so that your project's surplus can get redistributed to the MP of projects it is composed of before reaching sustainers.

The basin of the Fountain should always be the sustainers of projects.

*/

/// @notice The contract managing the state of all Money pools.
contract Fountain is IFountain, Ownable {
    using SafeMath for uint256;
    using SafeMath for uint8;
    using SafeERC20 for IERC20;
    using MoneyPool for MoneyPool.Data;

    /// @dev Wrap the sustain and collect transactions in unique locks to prevent reentrency.
    uint8 private lock1 = 1;
    uint8 private lock2 = 1;
    uint8 private lock3 = 1;
    modifier lockSustain() {
        require(lock1 == 1, "Fountain::sustainOwner LOCKED");
        lock1 = 0;
        _;
        lock1 = 1;
    }
    modifier lockCollect() {
        require(lock2 == 1, "Fountain::collectRedistributions: LOCKED");
        lock2 = 0;
        _;
        lock2 = 1;
    }
    modifier lockTap() {
        require(lock3 == 1, "Fountain:: tapSustainments LOCKED");
        lock3 = 0;
        _;
        lock3 = 1;
    }

    // --- private properties --- //

    /// @dev The official record of all Money pools ever created
    mapping(uint256 => MoneyPool.Data) private mps;

    // --- public properties --- //

    /// @notice a big number to base ticket issuance off of.
    uint256 public constant BASE_MP_WEIGHT = 1000000000E18;

    /// @notice The tickets handed out to Money pool sustainers. Each owner has their own set of tickets.
    mapping(address => Ticket) public override tickets;

    /// @notice The current cumulative amount redistributable from each owner's Money pools.
    mapping(address => uint256) public override redistributable;

    /// @notice The latest Money pool for each owner address
    mapping(address => uint256) public override latestMpId;

    /// @notice The total number of Money pools created, which is used for issuing Money pool IDs.
    /// @dev Money pools should have a ID > 0.
    uint256 public override mpCount = 0;

    /// @notice The treasury that manages funds.
    Treasury public treasury;

    /// @notice The contract currently only supports sustainments in dai.
    IERC20 public dai;

    /// @notice The token that surplus is converted into.
    IERC20 public flow;

    // --- external views --- //

    /**  
        @notice The properties of the given Money pool.
        @param _mpId The ID of the Money pool to get the properties of.
        @return _mp The Money pool.
    */
    function getMp(uint256 _mpId)
        external
        view
        override
        returns (MoneyPool.Data memory _mp)
    {
        _mp = mps[_mpId];
        require(_mp.id > 0, "Fountain::getMp: NOT_FOUND");
    }

    /**
        @notice The Money pool that's next up for an owner and not currently accepting payments.
        @param _owner The owner of the Money pool being looked for.
        @return _mp The Money pool.
    */
    function getQueuedMp(address _owner)
        external
        view
        override
        returns (MoneyPool.Data memory)
    {
        MoneyPool.Data memory _sMp = _standbyMp(_owner);
        MoneyPool.Data memory _aMp = _activeMp(_owner);
        if (_sMp.id > 0 && _aMp.id > 0) return _sMp;
        require(_aMp.id > 0, "Fountain::getQueuedMp: NOT_FOUND");
        return _aMp._nextUp();
    }

    /**
        @notice The properties of the Money pool that would be currently accepting sustainments.
        @param _owner The owner of the money pool being looked for.
        @return _mp The Money pool.
    */
    function getCurrentMp(address _owner)
        external
        view
        override
        returns (MoneyPool.Data memory _mp)
    {
        require(latestMpId[_owner] > 0, "Fountain::getCurrentMp: NOT_FOUND");

        _mp = _activeMp(_owner);
        if (_mp.id > 0) return _mp;

        _mp = _standbyMp(_owner);
        if (_mp.id > 0) return _mp;

        _mp = mps[latestMpId[_owner]];
        return _mp._nextUp();
    }

    /**
        @notice The amount left to be withdrawn by the Money pool's owner.
        @param _mpId The ID of the Money pool to get the available sustainment from.
        @return amount The amount.
    */
    function getTappableAmount(uint256 _mpId)
        external
        view
        override
        returns (uint256)
    {
        require(_mpId > 0, "Fountain::getTappableAmount:: NOT_FOUND");
        return mps[_mpId]._tappableAmount();
    }

    /** 
        @notice The amount of redistribution that can be claimed by the given address in the Fountain ecosystem.
        @dev This function runs the same routine as _redistributeAmount to determine the summed amount.
        Look there for more documentation.
        @param _beneficiary The address to get an amount for.
        @param _owner The owner of the Money pools to get an amount for.
        @return _amount The amount.
    */
    function getRedistributableAmount(address _beneficiary, address _owner)
        external
        view
        override
        returns (uint256)
    {
        return _redistributableAmount(_beneficiary, _owner);
    }

    // --- external transactions --- //

    constructor(IERC20 _dai, IERC20 _flow) public {
        dai = _dai;
        flow = _flow;
    }

    /**
        @notice Initializes an owner's tickets, which they'll need to configure their Money pool.
        @dev Deploys an owners redistribution share tokens.
        @param _name If this is the message sender's first Money pool configuration, this name is used for ERC-20 token's tracking surplus shares for this owner.
        @param _symbol The tokens symbol.
    */
    function initializeTicket(string calldata _name, string calldata _symbol)
        external
        override
    {
        require(
            tickets[msg.sender] == Ticket(0),
            "Fountain::initializeProject: ALREADY_INITIALIZED"
        );
        require(
            bytes(_name).length != 0 && bytes(_symbol).length != 0,
            "Fountain::configureMp: BAD_PARAMS"
        );
        tickets[msg.sender] = new Ticket(_name, _symbol);
        emit InitializeTicket(_name, _symbol);
    }

    /**
        @notice Configures the sustainability target and duration of the sender's current Money pool if it hasn't yet received sustainments, or
        sets the properties of the Money pool that will take effect once the current Money pool expires.
        @param _target The sustainability target to set.
        @param _duration The duration to set, measured in seconds.
        @param _want The token that the Money pool wants.
        @param _title The title of the Money pool.
        @param _link A link to information about the Money pool.
        @param _bias A number from 0-200 indicating how valuable a Money pool is compared to the owners previous Money pool, 
        effectively creating a recency bias.
        If the number is 200, each Money pool will be treated as twice as valuable than the previous, meaning sustainers get twice as much redistribution shares.
        If it's 100, each Money pool will have equal weight.
        If it's 1, each Money pool will have 1% of the previous Money pool's weight.
        @param _o The percentage of this Money pool's surplus to allocate to the owner.
        @param _b The percentage of this Money pool's surplus to allocate towards a beneficiary address. This can be another contract, or an end user address.
        An example would be a contract that allocates towards a specific purpose, such as Gitcoin grant matching.
        @param _bAddress The address of the beneficiary contract where a specified percentage is allocated.
        @return _mpId The ID of the Money pool that was successfully configured.
    */
    function configureMp(
        uint256 _target,
        uint256 _duration,
        IERC20 _want,
        string calldata _title,
        string calldata _link,
        uint8 _bias,
        uint8 _o,
        uint8 _b,
        address _bAddress
    ) external override returns (uint256) {
        require(
            tickets[msg.sender] != Ticket(0),
            "Fountain::configureMp: NEEDS_INITIALIZATION"
        );
        require(_duration >= 1, "Fountain::configureMp: TOO_SHORT");
        require(_want == dai, "Fountain::configureMp: UNSUPPORTED_WANT");
        require(_target > 0, "Fountain::configureMp: BAD_TARGET");
        require(_bias > 0 && _bias <= 200, "Fountain:configureMP: BAD_BIAS");
        require(
            bytes(_title).length > 0 && bytes(_title).length <= 32,
            "Fountain::configureMp: BAD_TITLE"
        );
        require(
            bytes(_link).length > 0 && bytes(_link).length <= 32,
            "Fountain::configureMp: BAD_LINK"
        );
        require(_o.add(_b) <= 100, "Fountain::configureMp: BAD_PERCENTAGES");

        MoneyPool.Data storage _mp = _mpToConfigure(msg.sender);

        // Reset the start time to now if there isn't an active Money pool.
        _mp._configure(
            _title,
            _link,
            _target,
            _duration,
            _want,
            _activeMp(msg.sender).id == 0 ? block.timestamp : _mp.start,
            _bias,
            _o,
            _b,
            _bAddress
        );

        emit ConfigureMp(
            _mp.id,
            _mp.owner,
            _mp.target,
            _mp.duration,
            _mp.want,
            _mp.title,
            _mp.link,
            _mp.bias,
            _o,
            _b,
            _bAddress
        );

        return _mp.id;
    }

    /** 
        @notice Sustain an owner's active Money pool.
        @dev If the amount results in surplus, redistribute the surplus proportionally to sustainers of the Money pool.
        @param _owner The owner of the Money pool to sustain.
        @param _amount Amount of sustainment.
        @param _want Must match the `want` token for the Money pool being sustained.
        @param _beneficiary The address to associate with this sustainment. This is usually mes.sender, but can be something else if the sender is making this sustainment on the beneficiary's behalf.
        @param _convertedFlowAmount The expected number of Flow to convert surplus into.
        @return _mpId The ID of the Money pool that was successfully sustained.
    */
    function sustainOwner(
        address _owner,
        uint256 _amount,
        IERC20 _want,
        address _beneficiary,
        uint256 _convertedFlowAmount
    ) external override lockSustain returns (uint256) {
        require(treasury != Treasury(0), "Fountain::sustainOwner: BAD_STATE");
        require(_amount > 0, "Fountain::sustainOwner: BAD_AMOUNT");

        // Find the Money pool that this sustainment should go to.
        MoneyPool.Data storage _mp = _mpToSustain(_owner);

        require(_want == _mp.want, "Fountain::sustainOwner: UNEXPECTED_WANT");

        _mp.want.safeTransferFrom(msg.sender, address(treasury), _amount);

        return _sustain(_mp, _amount, _beneficiary, _convertedFlowAmount);
    }

    /** 
        @notice A message sender can collect what's been redistributed to it by Money pools once they have expired.
        @param _owner The owner of the Money pools being collected from.
        @param _amount The amount of FLOW to collect.
    */
    function collectRedistributions(address _owner, uint256 _amount)
        external
        override
        lockCollect
    {
        require(treasury != Treasury(0), "Fountain::sustainOwner: BAD_STATE");
        uint256 _available = _redistributableAmount(msg.sender, _owner);
        require(
            _available >= _amount,
            "Fountain::collectRedistributions: INSUFFICIENT_FUNDS"
        );
        treasury.payout(msg.sender, flow, _amount);
        Ticket _ticket = tickets[_owner];
        _ticket.burn(msg.sender, _ticket.balanceOf(msg.sender));
        redistributable[_owner] = redistributable[_owner].sub(_amount);
        emit CollectRedistributions(msg.sender, _amount);
    }

    /**
        @notice A message sender can tap into funds that have been used to sustain it's Money pools.
        @param _mpId The ID of the Money pool to tap.
        @param _amount The amount to tap.
        @param _beneficiary The address to transfer the funds to.
    */
    function tapMp(
        uint256 _mpId,
        uint256 _amount,
        address _beneficiary
    ) external override lockTap {
        require(treasury != Treasury(0), "Fountain::sustainOwner: BAD_STATE");
        MoneyPool.Data storage _mp = mps[_mpId];
        require(
            _mp.owner == msg.sender,
            "Fountain::collectSustainment: UNAUTHORIZED"
        );
        require(
            _mp._tappableAmount() >= _amount,
            "Fountain::collectSustainment: INSUFFICIENT_FUNDS"
        );
        _mp._tap(_amount);
        treasury.payout(_beneficiary, _mp.want, _amount);
        emit TapMp(_mpId, msg.sender, _beneficiary, _amount, _mp.want);
    }

    /** 
        @notice Replaces the current treasury with a new one. All funds will move over.
        @param _newTreasury The new treasury.
    */
    function reassignTreasury(address _newTreasury)
        external
        override
        onlyOwner
    {
        require(
            _newTreasury != address(0),
            "Fountain::overthrowTreasury: ZERO_ADDRESS"
        );
        if (treasury == Treasury(0)) treasury = Treasury(_newTreasury);
        IERC20[] storage _tokens;
        _tokens.push(dai);
        treasury.overthrow(_newTreasury, _tokens);
    }

    /**
        @notice Allows the owner of the contract to withdraw phase 1 funds.
        @param _amount The amount to withdraw.
    */
    function withdrawPhase1Funds(uint256 _amount) external override onlyOwner {
        require(treasury != Treasury(0), "Fountain::sustainOwner: BAD_STATE");
        treasury.withdrawPhase1Funds(msg.sender, dai, _amount);
    }

    /**
        @notice Allows the owner of the contract to allocate phase 2 funds to Money pools.
        @dev Largely the same logic from the `sustainOwner` transaction.
        @param _owner The owner of the Money pool to fund.
        @param _amount The amount to fund.
        @param _want Must match the `want` token for the Money pool being sustained.
        @param _beneficiary The address to associate with this sustainment. This is usually mes.sender, but can be something else if the sender is making this sustainment on the beneficiary's behalf.
        @param _convertedFlowAmount The expected number of Flow to convert surplus into.
    */
    function allocatePhase2Funds(
        address _owner,
        uint256 _amount,
        IERC20 _want,
        address _beneficiary,
        uint256 _convertedFlowAmount
    ) external override onlyOwner {
        require(treasury != Treasury(0), "Fountain::sustainOwner: BAD_STATE");
        treasury.allocatePhase2Funds(_amount);

        // Find the Money pool that this sustainment should go to.
        MoneyPool.Data storage _mp = _mpToSustain(_owner);
        require(
            _want == _mp.want,
            "Fountain::allocatePhase2Funds: UNEXPECTED_WANT"
        );
        _sustain(_mp, _amount, _beneficiary, _convertedFlowAmount);
    }

    // --- private transactions --- //

    /** 
        @notice Sustain the provided Money pool.
        @param _mp The Money pool to sustain.
        @param _amount Amount of sustainment.
        @param _beneficiary The address to associate with this sustainment. This is usually mes.sender, but can be something else if the sender is making this sustainment on the beneficiary's behalf.
        @param _convertedFlowAmount The expected number of Flow to convert surplus into.
        @return _mpId The ID of the Money pool that was successfully sustained.
    */
    function _sustain(
        MoneyPool.Data storage _mp,
        uint256 _amount,
        address _beneficiary,
        uint256 _convertedFlowAmount
    ) private returns (uint256) {
        // Add the amount to the Money pool, which determines how much Flow was made available as a result.
        uint256 _surplus = _mp._add(_amount);
        if (_surplus > 0) {
            uint256 _overflowAmount =
                treasury.transform(
                    _surplus,
                    _mp.want,
                    _surplus.mul(_convertedFlowAmount).div(_amount)
                );
            redistributable[_mp.owner] = redistributable[_mp.owner].add(
                _overflowAmount
            );
        }

        Ticket _ticket = tickets[_mp.owner];
        uint256 _baseAmount = _mp.weight.mul(_amount).div(_mp.target);

        _ticket.mint(_beneficiary, _baseAmount.mul(_mp._s()).div(100));
        if (_mp.o > 0) _ticket.mint(_mp.owner, _baseAmount.mul(_mp.o).div(100));
        if (_mp.b > 0)
            _ticket.mint(_mp.bAddress, _baseAmount.mul(_mp.b).div(100));

        emit SustainMp(
            _mp.id,
            _mp.owner,
            _beneficiary,
            msg.sender,
            _amount,
            _mp.want
        );
        return _mp.id;
    }

    /** 
        @notice The Money pool that is configurable for this owner.
        @dev The sustainability of a Money pool cannot be updated if there have been sustainments made to it.
        @param _owner The address who owns the Money pool to look for.
        @return _mp The resulting Money pool.
    */
    function _mpToConfigure(address _owner)
        private
        returns (MoneyPool.Data storage _mp)
    {
        // Cannot update active moneyPool, check if there is a standby moneyPool
        _mp = _standbyMp(_owner);
        if (_mp.id > 0) return _mp;
        _mp = mps[latestMpId[_owner]];
        // If there's an active Money pool, its end time should correspond to the start time of the new Money pool.
        MoneyPool.Data memory _aMp = _activeMp(_owner);
        MoneyPool.Data storage _newMp =
            _initMp(
                _owner,
                _aMp.id > 0 ? _aMp.start.add(_aMp.duration) : block.timestamp,
                _aMp.id == 0 ? BASE_MP_WEIGHT : _aMp._derivedWeight()
            );
        if (_mp.id > 0) _newMp._basedOn(_mp);
        return _newMp;
    }

    /** 
        @notice The Money pool that is accepting sustainments for this owner.
        @dev Only active Money pools can be sustained.
        @param _owner The address who owns the Money pool to look for.
        @return _mp The resulting Money pool.
    */
    function _mpToSustain(address _owner)
        private
        returns (MoneyPool.Data storage _mp)
    {
        // Check if there is an active moneyPool
        _mp = _activeMp(_owner);
        if (_mp.id > 0) return _mp;
        // No active moneyPool found, check if there is a standby moneyPool
        _mp = _standbyMp(_owner);
        if (_mp.id > 0) return _mp;
        // No upcoming moneyPool found, clone the latest moneyPool
        _mp = mps[latestMpId[_owner]];
        require(_mp.id > 0, "Fountain::_mpToSustain: NOT_FOUND");
        // Use a start date that's a multiple of the duration.
        // This creates the effect that there have been scheduled Money pools ever since the `latest`, even if `latest` is a long time in the past.
        MoneyPool.Data storage _newMp =
            _initMp(_mp.owner, _mp._determineNextStart(), _mp._derivedWeight());
        _newMp._basedOn(_mp);
        return _newMp;
    }

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
        _newMp = mps[mpCount];
        _newMp._init(_owner, _start, mpCount, latestMpId[_owner], _weight);
        latestMpId[_owner] = mpCount;
    }

    // --- private views --- //

    /** 
        @notice The currently active Money pool for an owner.
        @param _owner The owner of the money pool being looked for.
        @return _mp The active Money pool.
    */
    function _activeMp(address _owner)
        private
        view
        returns (MoneyPool.Data storage _mp)
    {
        _mp = mps[latestMpId[_owner]];
        if (_mp.id == 0) return mps[0];
        // An Active moneyPool must be either the latest moneyPool or the
        // moneyPool immediately before it.
        if (_mp._state() == MoneyPool.State.Active) return _mp;
        _mp = mps[_mp.previous];
        if (_mp.id == 0 || _mp._state() != MoneyPool.State.Active)
            return mps[0];
    }

    /** 
        @notice An owner's edittable Money pool.
        @param _owner The owner of the money pool being looked for.
        @return _mp The standby Money pool.
    */
    function _standbyMp(address _owner)
        private
        view
        returns (MoneyPool.Data storage _mp)
    {
        _mp = mps[latestMpId[_owner]];
        if (_mp.id == 0) return mps[0];
        // There is no upcoming Money pool if the latest Money pool is not upcoming
        if (_mp._state() != MoneyPool.State.Standby) return mps[0];
    }

    /** 
        @notice The amount that the provided beneficiary has access to from the provided owner's Money pools.
        @param _beneficiary The account to check the balance of.
        @param _owner The owner of the Money pools being considered.
        @return _amount The amount that is redistributable.
    */
    function _redistributableAmount(address _beneficiary, address _owner)
        private
        view
        returns (uint256)
    {
        Ticket _ticket = tickets[_owner];
        uint256 _currentBalance = _ticket.balanceOf(_beneficiary);
        return
            redistributable[_owner].mul(_currentBalance).div(
                _ticket.totalSupply()
            );
    }
}
