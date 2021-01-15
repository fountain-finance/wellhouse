// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Tickets is ERC20, AccessControl {
    modifier onlyAdmin {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        _;
    }

    /// @notice The address that issued these tickets.
    address public issuer;

    /// @notice The token that these Tickets are redeemable for.
    IERC20 public redeemableFor;

    constructor(
        string memory _name,
        string memory _symbol,
        address _issuer,
        IERC20 _redeemableFor
    ) public ERC20(_name, _symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        issuer = _issuer;
        redeemableFor = _redeemableFor;
    }

    function mint(address _account, uint256 _amount) external onlyAdmin {
        return _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external onlyAdmin {
        return _burn(_account, _amount);
    }
}

contract TicketStand {
    using SafeMath for uint256;

    modifier onlyController {
        require(msg.sender == controller, "Store: UNAUTHORIZED");
        _;
    }

    // --- public properties --- //

    /// @notice The address controlling this Store.
    address public controller;

    /// @notice The Tickets handed out by owners. Each owner has their own Ticket contract.
    mapping(address => Tickets) public tickets;

    /// @notice The current cumulative amount of redeemable tokens redistributable to each owner's Ticket holders.
    mapping(address => mapping(IERC20 => uint256)) public redeemable;

    /// @notice The amount of each token that is transformable into the redeemable token for each owner
    mapping(address => mapping(IERC20 => mapping(IERC20 => uint256)))
        public transformable;

    // --- external views --- //

    /**
        @notice The amount of redistribution that can be claimed by the given address.
        @dev This function runs the same routine as _redistributeAmount to determine the summed amount.
        Look there for more documentation.
        @param _beneficiary The address to get an amount for.
        @param _owner The owner of the Tickets to get an amount for.
        @param _redeemableToken The token to base the value off of.
        @return _amount The amount.
    */
    function getRedeemableAmount(
        address _beneficiary,
        address _owner,
        IERC20 _redeemableToken
    ) external view returns (uint256) {
        Tickets _tickets = tickets[_owner];
        uint256 _currentBalance = _tickets.balanceOf(_beneficiary);
        return
            redeemable[_owner][_redeemableToken].mul(_currentBalance).div(
                _tickets.totalSupply()
            );
    }

    /**
        @notice The value that a Ticket can be redeemed for.
        @param _owner The owner of the Ticket to get a value for.
        @param _redeemableToken The token to base the value off of.
        @return _value The value.
    */
    function getCurrentTicketValue(address _owner, IERC20 _redeemableToken)
        external
        view
        returns (uint256)
    {
        Tickets _tickets = tickets[_owner];
        return redeemable[_owner][_redeemableToken].div(_tickets.totalSupply());
    }

    // --- external transactions --- //

    /**
        @notice Saves a Ticket to storage for the provided owner.
        @param _owner The owner of the Ticket.
        @param _tickets The Ticket to assign to the owner.
    */
    function issueTickets(address _owner, Tickets _tickets)
        external
        onlyController
    {
        tickets[_owner] = _tickets;
    }

    /**
        @notice Adds an amount to the total that can be redeemable for the given owner's Ticket holders.
        @param _owner The owner of the Ticket.
        @param _token The redeemable token to increment.
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
        @param _token The redeemable token to decrement.
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
        @param _amount The amount of `from` tokens to make transformable.
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
        @param _amount The amount of `from` tokens to decrement.
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
}
