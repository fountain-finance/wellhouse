// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./abstract/Store.sol";
import "./interfaces/ITicketStore.sol";

contract Tickets is ERC20, ITickets, AccessControl {
    modifier onlyAdmin {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        _;
    }

    /// @notice The address that issued these tickets.
    address public issuer;

    /// @notice The token that these Tickets are redeemable for.
    IERC20 public override rewardToken;

    constructor(
        string memory _name,
        string memory _symbol,
        address _issuer,
        IERC20 _rewardToken
    ) public ERC20(_name, _symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        issuer = _issuer;
        rewardToken = _rewardToken;
    }

    function DEFAULT_ADMIN_ROLE_() external pure override returns (bytes32) {
        return DEFAULT_ADMIN_ROLE;
    }

    function grantRole_(bytes32 role, address account) external override {
        return grantRole(role, account);
    }

    function revokeRole_(bytes32 role, address account) external override {
        return revokeRole(role, account);
    }

    function mint(address _account, uint256 _amount)
        external
        override
        onlyAdmin
    {
        return _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount)
        external
        override
        onlyAdmin
    {
        return _burn(_account, _amount);
    }
}

contract TicketStore is Store, ITicketStore {
    using SafeMath for uint256;

    modifier onlyAdmin {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "TicketStore: UNAUTHORIZED"
        );
        _;
    }

    // --- public properties --- //

    /// @notice The Tickets handed out by each issuer. Each issuer has their own Ticket contract.
    mapping(address => ITickets) public override tickets;

    /// @notice The current cumulative amount of redeemable tokens redistributable to each issuer's Ticket holders.
    mapping(address => mapping(IERC20 => uint256)) public redeemable;

    /// @notice The amount of each token that is swappable into the redeemable token for each issuer.
    mapping(address => mapping(IERC20 => mapping(IERC20 => uint256)))
        public
        override swappable;

    // --- external views --- //

    /**
        @notice The amount of redistribution that can be claimed by the given address.
        @dev This function runs the same routine as _redistributeAmount to determine the summed amount.
        Look there for more documentation.
        @param _holder The address to get an amount for.
        @param _issuer The issuer of the Tickets to get an amount for.
        @return _amount The amount.
    */
    function getRedeemableAmount(address _holder, address _issuer)
        external
        view
        override
        returns (uint256)
    {
        ITickets _tickets = tickets[_issuer];
        uint256 _totalSupply = _tickets.totalSupply();
        if (_totalSupply == 0) return 0;
        uint256 _currentBalance = _tickets.balanceOf(_holder);
        return
            redeemable[_issuer][_tickets.rewardToken()]
                .mul(_currentBalance)
                .div(_totalSupply);
    }

    /**
        @notice The value that a Ticket can be redeemed for.
        @param _issuer The issuer of the Ticket to get a value for.
        @return _value The value.
    */
    function getTicketValue(address _issuer)
        external
        view
        override
        returns (uint256)
    {
        ITickets _tickets = tickets[_issuer];
        return
            redeemable[_issuer][_tickets.rewardToken()].div(
                _tickets.totalSupply()
            );
    }

    /**
        @notice Gets the amount of an owner's tickets that a holder has.
        @param _issuer The issuer of the Ticket to get a value for.
        @param _holder The ticket holder to get a value for.
        @return _value The value.
    */
    function getTicketBalance(address _issuer, address _holder)
        external
        view
        override
        returns (uint256)
    {
        return tickets[_issuer].balanceOf(_holder);
    }

    /**
        @notice Gets the total circulating supply of an owner's tickets.
        @param _issuer The issuer of the Ticket to get a value for.
        @return _value The value.
    */
    function getTicketSupply(address _issuer)
        external
        view
        override
        returns (uint256)
    {
        return tickets[_issuer].totalSupply();
    }

    /**
        @notice Gets the reward token for the provided issuer's tickets.
        @param _issuer The issuer of the Ticket to get a value for.
        @return _value The value.
    */
    function getTicketRewardToken(address _issuer)
        external
        view
        override
        returns (IERC20)
    {
        return tickets[_issuer].rewardToken();
    }

    // --- external transactions --- //

    constructor() public {}

    /**
        @notice Saves a Ticket to storage for the provided issuer.
        @param _issuer The issuer of the Ticket.
        @param _tickets The Ticket to assign to the issuer.
    */
    function issueTickets(address _issuer, ITickets _tickets)
        external
        override
        onlyAdmin
    {
        tickets[_issuer] = _tickets;
    }

    /**
        @notice Adds an amount to the total that can be redeemable for the given issuer's Ticket holders.
        @param _issuer The issuer of the Ticket.
        @param _token The redeemable token to increment.
        @param _amount The amount to increment.
    */
    function addRedeemable(
        address _issuer,
        IERC20 _token,
        uint256 _amount
    ) external override onlyAdmin {
        redeemable[_issuer][_token] = redeemable[_issuer][_token].add(_amount);
    }

    /**
        @notice Subtracts an amount to the total that can be redeemable for the given issuer's Ticket holders.
        @param _issuer The issuer of the Ticket.
        @param _token The redeemable token to decrement.
        @param _amount The amount to decrement.
    */
    function subtractRedeemable(
        address _issuer,
        IERC20 _token,
        uint256 _amount
    ) external override onlyAdmin {
        redeemable[_issuer][_token] = redeemable[_issuer][_token].sub(_amount);
    }

    /**
        @notice Adds an amount that can be swappable from one token to another.
        @param _issuer The issuer of the Tickets responsible for the funds.
        @param _from The original token.
        @param _amount The amount of `from` tokens to make swappable.
        @param _to The token to swap into.
    */
    function addSwappable(
        address _issuer,
        IERC20 _from,
        uint256 _amount,
        IERC20 _to
    ) external override onlyAdmin {
        swappable[_issuer][_from][_to] = swappable[_issuer][_from][_to].add(
            _amount
        );
    }

    /**
        @notice Subtracts the amount that can be swapped from one token to another.
        @param _issuer The issuer of the Tickets responsible for the funds.
        @param _from The original token.
        @param _amount The amount of `from` tokens to decrement.
        @param _to The token to swap into.
    */
    function subtractSwappable(
        address _issuer,
        IERC20 _from,
        uint256 _amount,
        IERC20 _to
    ) external override onlyAdmin {
        swappable[_issuer][_from][_to] = swappable[_issuer][_from][_to].sub(
            _amount
        );
    }
}
