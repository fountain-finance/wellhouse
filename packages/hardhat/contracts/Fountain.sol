// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interfaces/ITreasury.sol";
import "./interfaces/IFountain.sol";

import "./Store.sol";

/// @notice The contract managing the state of all Money pools.
contract Fountain is IFountain, AccessControl {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using MoneyPool for MoneyPool.Data;

    /// @dev Wrap the sustain and collect transactions in unique locks to prevent reentrency.
    uint256 private lock1 = 1;
    uint256 private lock2 = 1;
    uint256 private lock3 = 1;
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

    modifier onlyAdmin {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        _;
    }

    // --- public properties --- //

    /// @notice The contract storing all state variables.
    /// @dev Immutable.
    Store public store;
    /// @notice The treasury that manages funds.
    /// @dev Reassignable by the owner.
    ITreasury public treasury;
    /// @notice A successor contract to this contract, if there is one.
    /// @dev Reassignable by the owner, but Ticket issuance must be migrated by owners.
    address public successor;
    /// @notice The contract currently only supports sustainments in dai.
    IERC20 public dai;
    /// @notice The token that surplus is converted into.
    IERC20 public reward;

    // --- external transactions --- //
    constructor(
        Store _store,
        IERC20 _dai,
        IERC20 _reward
    ) public {
        store = _store;
        dai = _dai;
        reward = _reward;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
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
            store.ticket(msg.sender) == Ticket(0),
            "Fountain::initializeProject: ALREADY_INITIALIZED"
        );
        require(
            bytes(_name).length != 0 && bytes(_symbol).length != 0,
            "Fountain::configureMp: BAD_PARAMS"
        );
        store.assignTicket(msg.sender, new Ticket(_name, _symbol));
        emit InitializeTicket(msg.sender, _name, _symbol);
    }

    /**
        @notice Configures the sustainability target and duration of the sender's current Money pool if it hasn't yet received sustainments, or
        sets the properties of the Money pool that will take effect once the current Money pool expires.
        @param _target The sustainability target to set.
        @param _duration The duration to set, measured in seconds.
        @param _want The token that the Money pool wants.
        @param _title The title of the Money pool.
        @param _link A link to information about the Money pool.
        @param _bias A number from 70-130 indicating how valuable a Money pool is compared to the owners previous Money pool,
        effectively creating a recency bias.
        If it's 100, each Money pool will have equal weight.
        If the number is 130, each Money pool will be treated as 1.3 times as valuable than the previous, meaning sustainers get twice as much redistribution shares.
        If it's 0.7, each Money pool will be 0.7 times as valuable as the previous Money pool's weight.
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
        uint256 _bias,
        uint256 _o,
        uint256 _b,
        address _bAddress
    ) external override returns (uint256) {
        require(
            store.ticket(msg.sender) != Ticket(0),
            "Fountain::configureMp: NEEDS_INITIALIZATION"
        );
        require(_duration >= 6, "Fountain::configureMp: TOO_SHORT");
        require(_want == dai, "Fountain::configureMp: UNSUPPORTED_WANT");
        require(_target > 0, "Fountain::configureMp: BAD_TARGET");
        require(_bias > 70 && _bias <= 130, "Fountain:configureMP: BAD_BIAS");
        require(
            bytes(_title).length > 0 && bytes(_title).length <= 32,
            "Fountain::configureMp: BAD_TITLE"
        );
        require(
            bytes(_link).length > 0 && bytes(_link).length <= 32,
            "Fountain::configureMp: BAD_LINK"
        );
        require(_o.add(_b) <= 100, "Fountain::configureMp: BAD_PERCENTAGES");
        MoneyPool.Data memory _mp = store.standbyMp(msg.sender);
        // Reset the start time to now if there isn't an active Money pool.
        _mp = store.configureMpDescription(_mp.id, _title, _link);
        _mp = store.configureMpFundingSchedule(
            _mp.id,
            _target,
            _duration,
            _want,
            store.activeMp(msg.sender).id == 0 ? block.timestamp : _mp.start
        );
        _mp = store.configureMpRedistribution(_mp.id, _bias, _o, _b, _bAddress);
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
        @param _expectedConvertedAmount The expected number of reward tokens to convert surplus into.
        @return _mpId The ID of the Money pool that was successfully sustained.
    */
    function sustainOwner(
        address _owner,
        uint256 _amount,
        IERC20 _want,
        address _beneficiary,
        uint256 _expectedConvertedAmount
    ) external override lockSustain returns (uint256) {
        require(treasury != ITreasury(0), "Fountain::sustainOwner: BAD_STATE");
        require(_amount > 0, "Fountain::sustainOwner: BAD_AMOUNT");
        // Find the Money pool that this sustainment should go to.
        MoneyPool.Data memory _mp = store.activeMp(_owner);
        require(_want == _mp.want, "Fountain::sustainOwner: UNEXPECTED_WANT");
        _mp.want.safeTransferFrom(msg.sender, address(treasury), _amount);
        // Add the amount to the Money pool, which determines how much Flow was made available as a result.
        uint256 _surplus = store.addToMp(_mp.id, _amount);
        if (_surplus > 0) {
            uint256 _overflowAmount =
                treasury.transform(
                    _mp.want,
                    _surplus,
                    reward,
                    _surplus.mul(_expectedConvertedAmount).div(_amount)
                );
            store.addRedeemable(_mp.owner, _overflowAmount);
        }
        store.ticket(_mp.owner).mint(_beneficiary, _mp._weighted(_amount));
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
        @notice A message sender can collect what's been redistributed to it by Money pools once they have expired.
        @param _owner The owner of the Money pools being collected from.
        @param _amount The amount of FLOW to collect.
    */
    function redeem(address _owner, uint256 _amount)
        external
        override
        lockCollect
    {
        require(treasury != ITreasury(0), "Fountain::redeem: BAD_STATE");
        uint256 _available = store.getRedeemableAmount(msg.sender, _owner);
        require(_available >= _amount, "Fountain::redeem: INSUFFICIENT_FUNDS");
        treasury.payout(msg.sender, reward, _amount);
        Ticket _ticket = store.ticket(_owner);
        _ticket.burn(msg.sender, _ticket.balanceOf(msg.sender));
        store.subtractRedeemable(_owner, _amount);
        emit Redeem(msg.sender, _amount);
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
        require(treasury != ITreasury(0), "Fountain::tapMp: BAD_STATE");
        MoneyPool.Data memory _mp = store.getMp(_mpId);
        require(
            _mp.owner == msg.sender,
            "Fountain::collectSustainment: UNAUTHORIZED"
        );
        require(
            _mp._tappableAmount() >= _amount,
            "Fountain::collectSustainment: INSUFFICIENT_FUNDS"
        );
        store.tapFromMp(_mp.id, _amount);
        treasury.payout(_beneficiary, _mp.want, _amount);
        emit TapMp(_mpId, msg.sender, _beneficiary, _amount, _mp.want);
    }

    /**
        @notice Mints all tickets reserved for owners and beneficiary addresses from the Money pools of the specified owner.
        @param _owner The owner whose Money pools are being iterated through.
    */
    function mintReservedTickets(address _owner) external override {
        Ticket _ticket = store.ticket(_owner);
        require(
            _ticket != Ticket(0),
            "Fountain::mintReservedTickets: NOT_FOUND"
        );
        MoneyPool.Data memory _mp = store.getMp(store.latestMpId(_owner));
        while (_mp.id > 0 && !_mp.hasMintedReserves && _mp.total > _mp.target) {
            if (_mp._state() == MoneyPool.State.Redistributing) {
                uint256 _baseAmount =
                    _mp.weight.mul(_mp.total.sub(_mp.target)).div(_mp.target);
                if (_mp.o > 0)
                    _ticket.mint(_mp.owner, _baseAmount.mul(_mp.o).div(100));
                if (_mp.b > 0)
                    _ticket.mint(_mp.bAddress, _baseAmount.mul(_mp.b).div(100));
                store.markMpReservesAsMinted(_mp.id);
            }
            _mp = store.getMp(_mp.previous);
        }
    }

    /**
        @notice Replaces the current treasury with a new one. All funds will move over.
        @param _newTreasury The new treasury.
    */
    function appointTreasury(ITreasury _newTreasury)
        external
        override
        onlyAdmin
    {
        require(
            _newTreasury != ITreasury(0),
            "Fountain::appointTreasury: ZERO_ADDRESS"
        );
        require(
            _newTreasury.fountain() == address(this),
            "Fountain::appointTreasury: INCOMPATIBLE"
        );
        if (treasury != ITreasury(0)) {
            IERC20[] storage _tokens;
            _tokens.push(dai);
            treasury.transition(address(_newTreasury), _tokens);
        }
        treasury = _newTreasury;
    }

    /**
        @notice Appoints a successor to this contracts that Ticket owners can migrate to.
        @param _successor The successor contract.
    */
    function appointSuccessor(address _successor) external override onlyAdmin {
        require(_successor != address(0), "Fountain::migrate: ZERO_ADDRESS");
        successor = _successor;
    }

    /**
        @notice Allows a successor contract to manage an owner's Tickets.
        @dev One way migration.
    */
    function migrate() external override {
        require(successor != address(0), "Fountain::migrate: BAD_STATE");
        Ticket _ticket = store.ticket(msg.sender);
        require(_ticket != Ticket(0), "Fountain::migrate: NOT_FOUND");
        require(
            !_ticket.hasRole(_ticket.DEFAULT_ADMIN_ROLE(), successor),
            "Fountain::migrate: ALREADY_MIGRATED"
        );
        _ticket.grantRole(_ticket.DEFAULT_ADMIN_ROLE(), successor);
        _ticket.revokeRole(_ticket.DEFAULT_ADMIN_ROLE(), address(this));
    }

    /**
        @notice Allows the owner of the contract to withdraw phase 1 funds.
        @param _amount The amount to withdraw.
    */
    function withdrawFunds(uint256 _amount) external override onlyAdmin {
        require(treasury != ITreasury(0), "Fountain::withdrawFunds: BAD_STATE");
        treasury.withdraw(msg.sender, dai, _amount);
    }
}
