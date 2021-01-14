// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interfaces/ITreasury.sol";
import "./interfaces/IController.sol";

import "./Store.sol";

/// @notice The contract managing the state of all Money pools.
contract Controller is IController, AccessControl {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using MoneyPool for MoneyPool.Data;

    /// @dev Wrap the sustain and collect transactions in unique locks to prevent reentrency.
    uint256 private lock1 = 1;
    uint256 private lock2 = 1;
    uint256 private lock3 = 1;
    modifier lockSustain() {
        require(lock1 == 1, "Controller::sustainOwner LOCKED");
        lock1 = 0;
        _;
        lock1 = 1;
    }
    modifier lockRedeem() {
        require(lock2 == 1, "Controller::redeem: LOCKED");
        lock2 = 0;
        _;
        lock2 = 1;
    }
    modifier lockTap() {
        require(lock3 == 1, "Controller:: tapSustainments LOCKED");
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
    /// @notice Proposals for successor contracts to this contract.
    /// @dev Anyone can propose a successor contract, but Ticket issuance must be migrated by owners.
    mapping(address => address) public successor;
    /// @notice If a particular token is allowed as a `want` token of a Money pool.
    mapping(IERC20 => bool) public wantTokenIsAllowed;
    /// @notice Tokens that are allowed to be want tokens.
    IERC20[] public wantTokenAllowList;
    /// @notice The token that surplus is converted into.
    IERC20 public rewardToken;

    // --- external transactions --- //
    constructor(
        Store _store,
        IERC20 _rewardToken,
        IERC20[] memory _wantTokenAllowList
    ) public {
        store = _store;
        rewardToken = _rewardToken;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        for (uint256 i = 0; i < _wantTokenAllowList.length; i++)
            wantTokenIsAllowed[_wantTokenAllowList[i]] = true;

        wantTokenAllowList = _wantTokenAllowList;
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
            "Controller::initializeProject: ALREADY_INITIALIZED"
        );
        require(
            bytes(_name).length != 0 && bytes(_symbol).length != 0,
            "Controller::configureMp: BAD_PARAMS"
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

        MoneyPool.Data memory _mp = store.standbyMp(msg.sender);

        _mp.title = _title;
        _mp.link = _link;
        _mp.target = _target;
        _mp.duration = _duration;
        _mp.want = _want;
        // Reset the start time to now if there isn't an active Money pool.
        _mp.start = store.activeMp(msg.sender).id == 0
            ? block.timestamp
            : _mp.start;
        _mp.bias = _bias;
        _mp.o = _o;
        _mp.b = _b;
        _mp.bAddress = _bAddress;

        store.saveMp(_mp);

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
        } else {
            _mp.want.safeTransferFrom(msg.sender, address(treasury), _amount);
        }

        store.saveMp(_mp);

        // Exchange any surplus for the reward.
        if (_surplus > 0) {
            // Transforming during a sustainment might prove to be too expensive.
            // Might wanna make transforms happen with async transactions.
            uint256 _overflowAmount =
                treasury.transform(
                    _mp.want,
                    _surplus,
                    rewardToken,
                    _surplus.mul(_expectedConvertedAmount).div(_amount)
                );
            store.addRedeemable(_mp.owner, rewardToken, _overflowAmount);
        }

        store.ticket(_mp.owner).mint(
            _beneficiary,
            _mp._weighted(_amount, _mp._s())
        );
        emit SustainMp(
            _mp.id,
            _mp.owner,
            _beneficiary,
            msg.sender,
            _amount,
            _mp.want,
            store.getCurrentTicketValue(_mp.owner, rewardToken)
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
        lockRedeem
    {
        require(treasury != ITreasury(0), "Controller::redeem: BAD_STATE");
        uint256 _redeemableAmount =
            store.getRedeemableAmount(msg.sender, _owner, rewardToken);
        require(
            _redeemableAmount >= _amount,
            "Controller::redeem: INSUFFICIENT_FUNDS"
        );
        Ticket _ticket = store.ticket(_owner);
        _ticket.burn(msg.sender, _amount);
        store.subtractRedeemable(_owner, rewardToken, _amount);
        treasury.payout(msg.sender, rewardToken, _amount);
        require(
            _redeemableAmount.sub(_amount) ==
                store.getRedeemableAmount(msg.sender, _owner, rewardToken),
            "Controller::redeem: POSTCONDITION_FAILED"
        );
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
        require(
            _tappableAmount.sub(_amount) == store.getTappableAmount(_mp.id),
            "Controller::redeem: POSTCONDITION_FAILED"
        );
        emit TapMp(_mpId, msg.sender, _beneficiary, _amount, _mp.want);
    }

    /**
        @notice Mints all Tickets reserved for owners and beneficiary addresses from the Money pools of the specified owner.
        @param _owner The owner whose Money pools are being iterated through.
    */
    function mintReservedTickets(address _owner) external override {
        Ticket _ticket = store.ticket(_owner);
        require(
            _ticket != Ticket(0),
            "Controller::mintReservedTickets: NOT_FOUND"
        );
        MoneyPool.Data memory _mp = store.getMp(store.latestMpId(_owner));
        while (_mp.id > 0 && !_mp.hasMintedReserves && _mp.total > _mp.target) {
            if (_mp._state() == MoneyPool.State.Redistributing) {
                uint256 _surplus = _mp.total.sub(_mp.target);
                if (_surplus > 0) {
                    if (_mp.o > 0)
                        _ticket.mint(_mp.owner, _mp._weighted(_surplus, _mp.o));
                    if (_mp.b > 0)
                        _ticket.mint(
                            _mp.bAddress,
                            _mp._weighted(_surplus, _mp.b)
                        );
                }
                _mp.hasMintedReserves = true;
                store.saveMp(_mp);
            }
            _mp = store.getMp(_mp.previous);
        }
    }

    /**
        @notice Proposes a successor to this contracts that Ticket owners can migrate to.
        @param _successor The successor contract.
    */
    function proposeSuccessor(address _successor) external override {
        require(_successor != address(0), "Controller::migrate: ZERO_ADDRESS");
        successor[msg.sender] = _successor;
    }

    /**
        @notice Allows an owner to migrate their Tickets to a proposed successor contract.
        @dev One way migration.
    */
    function migrate(address _proposer) external override {
        address _successor = successor[_proposer];
        require(_successor != address(0), "Controller::migrate: BAD_STATE");
        Ticket _ticket = store.ticket(msg.sender);
        require(_ticket != Ticket(0), "Controller::migrate: NOT_FOUND");
        require(
            !_ticket.hasRole(_ticket.DEFAULT_ADMIN_ROLE(), _successor),
            "Controller::migrate: ALREADY_MIGRATED"
        );
        _ticket.grantRole(_ticket.DEFAULT_ADMIN_ROLE(), _successor);
        _ticket.revokeRole(_ticket.DEFAULT_ADMIN_ROLE(), address(this));
    }

    /**
        @notice Allows the owner of the contract to withdraw phase 1 funds.
        @param _amount The amount to withdraw.
    */
    function withdrawFunds(uint256 _amount, IERC20 _token)
        external
        override
        onlyAdmin
    {
        require(
            treasury != ITreasury(0),
            "Controller::withdrawFunds: BAD_STATE"
        );
        treasury.withdraw(msg.sender, _token, _amount);
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
            "Controller::appointTreasury: ZERO_ADDRESS"
        );
        require(
            _newTreasury.controller() == address(this),
            "Controller::appointTreasury: INCOMPATIBLE"
        );

        if (treasury != ITreasury(0))
            treasury.transition(address(_newTreasury), wantTokenAllowList);

        treasury = _newTreasury;
    }
}
