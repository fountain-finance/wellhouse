// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interfaces/ITreasury.sol";
import "./interfaces/IController.sol";

import "./stores/MpStore.sol";
import "./stores/TicketStore.sol";

/**
@notice The contract managing the state of all Money pools.
*/
contract Controller is IController, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using MoneyPool for MoneyPool.Data;

    /// @dev Limit sustain, redeem, swap, and tap to being called one at a time.
    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "Controller: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    // --- private properties --- //

    // If a particular token is allowed as a `want` token of a Money pool.
    mapping(IERC20 => bool) private wantTokenIsAllowed;

    // --- public properties --- //

    /// @notice The contract storing all Money pool state variables.
    /// @dev Immutable.
    MpStore public store;

    /// @notice The contract that manages the Tickets.
    /// @dev Immutable.
    TicketStore public ticketStore;

    /// @notice The treasury that manages funds.
    /// @dev Reassignable by the owner.
    ITreasury public treasury;

    /// @notice Tokens that are allowed to be want tokens.
    IERC20[] public wantTokenAllowList;

    // --- external transactions --- //

    constructor(IERC20[] memory _wantTokenAllowList) public {
        store = new MpStore();
        ticketStore = new TicketStore();

        for (uint256 i = 0; i < _wantTokenAllowList.length; i++)
            wantTokenIsAllowed[_wantTokenAllowList[i]] = true;

        wantTokenAllowList = _wantTokenAllowList;
    }

    /**
        @notice Initializes an owner's tickets, which they'll need to configure their Money pool.
        @dev Deploys an owners redistribution share tokens.
        @param _name If this is the message sender's first Money pool configuration, this name is used for ERC-20 token's tracking surplus shares for this owner.
        @param _symbol The tokens symbol.
        @param _rewardToken The token that the ticket is redeemable for.
    */
    function initializeTickets(
        string calldata _name,
        string calldata _symbol,
        IERC20 _rewardToken
    ) external override {
        require(
            ticketStore.tickets(msg.sender) == Tickets(0),
            "Controller::initializeProject: ALREADY_INITIALIZED"
        );
        require(
            bytes(_name).length != 0 && bytes(_symbol).length != 0,
            "Controller::configureMp: BAD_PARAMS"
        );
        ticketStore.issueTickets(
            msg.sender,
            new Tickets(_name, _symbol, msg.sender, _rewardToken)
        );
        emit InitializeTickets(msg.sender, _name, _symbol, _rewardToken);
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
        Tickets _tickets = ticketStore.tickets(msg.sender);
        require(
            _tickets != Tickets(0),
            "Controller::configureMp: NEEDS_INITIALIZATION"
        );
        require(_duration >= 6, "Controller::configureMp: TOO_SHORT");
        require(_target > 0, "Controller::configureMp: BAD_TARGET");
        require(
            wantTokenIsAllowed[_want],
            "Controller::configureMp: UNSUPPORTED_WANT"
        );
        require(_bias > 70 && _bias <= 130, "Controller:configureMP: BAD_BIAS");
        require(
            bytes(_title).length > 0 && bytes(_title).length <= 64,
            "Controller::configureMp: BAD_TITLE"
        );
        require(
            bytes(_link).length > 0 && bytes(_link).length <= 64,
            "Controller::configureMp: BAD_LINK"
        );
        require(_o.add(_b) <= 100, "Controller::configureMp: BAD_PERCENTAGES");

        MoneyPool.Data memory _mp = store.getStandbyMp(msg.sender);

        _mp.title = _title;
        _mp.link = _link;
        _mp.target = _target;
        _mp.duration = _duration;
        _mp.want = _want;
        // Reset the start time to now if there isn't an active Money pool.
        _mp.start = store.getActiveMp(msg.sender).id == 0
            ? block.timestamp
            : _mp.start;
        _mp.bias = _bias;
        _mp.o = _o;
        _mp.b = _b;
        _mp.bAddress = _bAddress;

        store.saveMp(_mp);
        store.trackAcceptedToken(msg.sender, _tickets.rewardToken(), _want);

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
        @return _mpId The ID of the Money pool that was successfully sustained.
    */
    function sustainOwner(
        address _owner,
        uint256 _amount,
        IERC20 _want,
        address _beneficiary
    ) external override lock returns (uint256) {
        require(
            treasury != ITreasury(0),
            "Controller::sustainOwner: BAD_STATE"
        );
        require(_amount > 0, "Controller::sustainOwner: BAD_AMOUNT");
        // Find the Money pool that this sustainment should go to.
        MoneyPool.Data memory _mp = store.activeMp(_owner);
        require(_want == _mp.want, "Controller::sustainOwner: UNEXPECTED_WANT");

        // Add the amount to the Money pool, which determines how much Flow was made available as a result.
        _mp.total = _mp.total.add(_amount);
        uint256 _surplus =
            _mp.total > _mp.target ? _mp.total.sub(_mp.target) : 0;

        // If the owner is sustaining themselves and theres no surplus, auto tap.
        if (_mp.owner == msg.sender && _surplus < _amount) {
            _mp.tapped = _mp.tapped.add(_amount.sub(_surplus));
            // Transfer the surplus only.
            if (_surplus > 0) {
                _mp.want.safeTransferFrom(
                    msg.sender,
                    address(treasury),
                    _surplus
                );
            }
            emit TapMp(_mp.id, msg.sender, msg.sender, _surplus, _mp.want);
        } else {
            _mp.want.safeTransferFrom(msg.sender, address(treasury), _amount);
        }
        store.saveMp(_mp);
        Tickets _tickets = ticketStore.tickets(_mp.owner);
        if (_surplus > 0) {
            ticketStore.addSwappable(
                _mp.owner,
                _mp.want,
                _surplus,
                _tickets.rewardToken()
            );
        }
        _tickets.mint(_beneficiary, _mp._weighted(_amount, _mp._s()));
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
        @notice Swaps any pending surplus from an owner's `want` token to the redeemable token.
        @param _from The token to swap from.
        @param _amount Amount to swap.
        @param _to The token to swap to.
        @param _expectedSwappedAmount The amount of redeemable tokens  from `want` tokens.
    */
    function swap(
        address _owner,
        IERC20 _from,
        uint256 _amount,
        IERC20 _to,
        uint256 _expectedSwappedAmount
    ) external override lock {
        require(_amount > 0, "Controller::swap: BAD_AMOUNT");
        uint256 _swappable = ticketStore.swappable(_owner, _from, _to);
        require(_swappable >= _amount, "Controller::swap: INSUFFICIENT_FUNDS");
        uint256 _swappedAmount =
            treasury.swap(_from, _amount, _to, _expectedSwappedAmount);
        ticketStore.addRedeemable(_owner, _to, _swappedAmount);
        ticketStore.subtractSwappable(_owner, _from, _amount, _to);
        emit Swap(_owner, _from, _amount, _to, _swappedAmount);
    }

    /**
        @notice A message sender can collect what's been redistributed to it by Money pools once they have expired.
        @param _owner The owner of the Money pools being collected from.
        @param _amount The amount of FLOW to collect.
    */
    function redeem(address _owner, uint256 _amount) external override lock {
        require(treasury != ITreasury(0), "Controller::redeem: BAD_STATE");
        Tickets _tickets = ticketStore.tickets(_owner);
        IERC20 _rewardToken = _tickets.rewardToken();
        uint256 _redeemableAmount =
            ticketStore.getRedeemableAmount(msg.sender, _owner);
        require(
            _redeemableAmount >= _amount,
            "Controller::redeem: INSUFFICIENT_FUNDS"
        );
        _tickets.burn(msg.sender, _amount);
        ticketStore.subtractRedeemable(_owner, _rewardToken, _amount);
        treasury.payout(msg.sender, _rewardToken, _amount);
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
    ) external override lock {
        require(treasury != ITreasury(0), "Controller::tapMp: BAD_STATE");
        MoneyPool.Data memory _mp = store.getMp(_mpId);
        uint256 _tappableAmount = _mp._tappableAmount();
        require(
            _mp.owner == msg.sender,
            "Controller::collectSustainment: UNAUTHORIZED"
        );
        require(
            _tappableAmount >= _amount,
            "Controller::collectSustainment: INSUFFICIENT_FUNDS"
        );
        _mp.tapped = _mp.tapped.add(_amount);
        store.saveMp(_mp);
        treasury.payout(_beneficiary, _mp.want, _amount);
        emit TapMp(_mpId, msg.sender, _beneficiary, _amount, _mp.want);
    }

    /**
        @notice Mints all Tickets reserved for owners and beneficiary addresses from the Money pools of the specified owner.
        @param _owner The owner whose Money pools are being iterated through.
    */
    function mintReservedTickets(address _owner) external override {
        Tickets _tickets = ticketStore.tickets(_owner);
        require(
            _tickets != Tickets(0),
            "Controller::mintReservedTickets: NOT_FOUND"
        );
        MoneyPool.Data memory _mp = store.getMp(store.latestMpId(_owner));
        while (_mp.id > 0 && !_mp.hasMintedReserves && _mp.total > _mp.target) {
            if (_mp._state() == MoneyPool.State.Redistributing) {
                uint256 _surplus = _mp.total.sub(_mp.target);
                if (_surplus > 0) {
                    if (_mp.o > 0)
                        _tickets.mint(
                            _mp.owner,
                            _mp._weighted(_surplus, _mp.o)
                        );
                    if (_mp.b > 0)
                        _tickets.mint(
                            _mp.bAddress,
                            _mp._weighted(_surplus, _mp.b)
                        );
                }
                _mp.hasMintedReserves = true;
                store.saveMp(_mp);
            }
            _mp = store.getMp(_mp.previous);
        }
        emit MintReservedTickets(msg.sender, _owner);
    }

    /**
        @notice Cleans the tracking array for an owner and a redeemable token.
        @dev This rarely needs to get called, if ever.
        @dev It's only useful if an owner has iterated through many `want` tokens that are just taking up space.
        @param _owner The owner of the Tickets responsible for the funds.
        @param _rewardToken The redeemable token to clean accepted tokens for.
    */
    function cleanTrackedWantedTokens(address _owner, IERC20 _rewardToken)
        external
        override
    {
        IERC20[] memory _currentWantedTokens =
            store.getWantedTokens(_owner, _rewardToken);
        require(
            _currentWantedTokens.length > 0,
            "Controller::cleanTrackedAcceptedTokens: NO_OP"
        );
        store.clearWantedTokens(_owner, _rewardToken);
        MoneyPool.Data memory _cMp = store.getCurrentMp(_owner);
        for (uint256 i = 0; i < _currentWantedTokens.length; i++) {
            IERC20 _wantedToken = _currentWantedTokens[i];
            if (
                _cMp.want == _wantedToken ||
                ticketStore.swappable(_owner, _wantedToken, _rewardToken) > 0
            ) {
                store.trackAcceptedToken(
                    msg.sender,
                    _rewardToken,
                    _wantedToken
                );
            }
        }
    }

    /**
        @notice Gives admin access to the Ticket Stand.
        @dev Make sure you know what you're doing.
        @dev _newAdmin The new admin of the Ticket Stand.
    */
    function appointTicketStandAdmin(address _newAdmin)
        external
        override
        onlyOwner
    {
        ticketStore.grantRole(ticketStore.DEFAULT_ADMIN_ROLE(), _newAdmin);
    }

    /**
        @notice Gives admin access to the Money pool store.
        @dev Make sure you know what you're doing.
        @dev _newAdmin The new admin of the Money pool store.
    */
    function appointMpStoreAdmin(address _newOwner)
        external
        override
        onlyOwner
    {
        store.grantRole(ticketStore.DEFAULT_ADMIN_ROLE(), _newOwner);
    }

    /**
        @notice Allows an owner to migrate their Tickets to a proposed successor contract.
        @dev Make sure you know what you're doing.
        @dev One way migration.
    */
    function migrateTickets(address _newController) external override {
        Tickets _tickets = ticketStore.tickets(msg.sender);
        require(_tickets != Tickets(0), "Controller::migrate: NOT_FOUND");
        require(
            !_tickets.hasRole(_tickets.DEFAULT_ADMIN_ROLE(), _newController),
            "Controller::migrate: ALREADY_MIGRATED"
        );
        _tickets.grantRole(_tickets.DEFAULT_ADMIN_ROLE(), _newController);
        _tickets.revokeRole(_tickets.DEFAULT_ADMIN_ROLE(), address(this));
        emit MigrateTickets(_newController);
    }

    /**
        @notice Allows the owner of the contract to withdraw phase 1 funds.
        @param _amount The amount to withdraw.
    */
    function withdrawFunds(uint256 _amount, IERC20 _token)
        external
        override
        onlyOwner
    {
        require(
            treasury != ITreasury(0),
            "Controller::withdrawFunds: BAD_STATE"
        );
        treasury.withdraw(msg.sender, _token, _amount);
        emit WithdrawFunds(_token, _amount);
    }

    /**
        @notice Replaces the current treasury with a new one. All funds will move over.
        @param _newTreasury The new treasury.
    */
    function appointTreasury(ITreasury _newTreasury)
        external
        override
        onlyOwner
    {
        require(
            _newTreasury != ITreasury(0),
            "Controller::appointTreasury: ZERO_ADDRESS"
        );
        require(
            _newTreasury.controller() == address(this),
            "Controller::appointTreasury: INCOMPATIBLE"
        );

        if (treasury != ITreasury(0))
            treasury.transition(address(_newTreasury), wantTokenAllowList);

        treasury = _newTreasury;
        emit AppointTreasury(_newTreasury);
    }
}
