// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import {
    UniswapV2Router02
} from "@uniswap/v2-periphery/contracts/UniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./../interfaces/IController.sol";
import "./../interfaces/ITickets.sol";

abstract contract MoneyPoolAdmin is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct MpConfigurationProposal {
        uint256 target;
        uint256 duration;
        IERC20 want;
        string title;
        string link;
        uint256 bias;
        uint256 o;
        uint256 b;
        address bAddress;
    }

    /// @notice The contract that manages the Tickets.
    IController public controller;

    /// @dev The address allowed to redeem from this Money pool.
    address public redeemer;

    /// @dev The address allowed to tap this Money pool.
    address public tapper;

    /// @dev The latest proposed Money pool configuration.
    MpConfigurationProposal public proposedMpReconfiguration;

    /// @dev The deadline for approving the latest Money pool configuration proposal.
    uint256 public proposalDeadline;

    //TODO
    UniswapV2Router02 public router;

    /// @notice Emitted when a new Controller contract is set.
    event ResetController(
        IController indexed previousController,
        IController indexed newController
    );

    constructor(
        IController _controller,
        string memory _name,
        string memory _symbol,
        IERC20 _rewardToken,
        UniswapV2Router02 _router
    ) internal {
        IMpStore _mpStore = _controller.mpStore();
        ITicketStore _ticketStore = _controller.ticketStore();
        _mpStore.claimOwnership();
        _ticketStore.claimOwnership();
        appointController(_controller);
        controller.issueTickets(_name, _symbol, _rewardToken);
        router = _router;
        redeemer = msg.sender;
    }

    function appointController(IController _controller) public onlyOwner {
        IMpStore _mpStore = _controller.mpStore();
        ITicketStore _ticketStore = _controller.ticketStore();
        _ticketStore.grantRole_(
            _ticketStore.DEFAULT_ADMIN_ROLE_(),
            address(_controller)
        );
        _mpStore.grantRole_(
            _mpStore.DEFAULT_ADMIN_ROLE_(),
            address(_controller)
        );
        controller = _controller;
        controller.setAdmin(address(this));
    }

    function deprecateController(IController _controller) external onlyOwner {
        IMpStore _mpStore = controller.mpStore();
        ITicketStore _ticketStore = controller.ticketStore();
        _ticketStore.revokeRole_(
            _ticketStore.DEFAULT_ADMIN_ROLE_(),
            address(_controller)
        );
        _mpStore.revokeRole_(
            _ticketStore.DEFAULT_ADMIN_ROLE_(),
            address(_controller)
        );
    }

    /**
        @notice This allows the contract owner to collect funds from your Money pool.
        @param _mpId The ID of the Money pool to collect funds from.
        @param _amount The amount to tap into.
    */
    function tapMp(uint256 _mpId, uint256 _amount) external {
        require(msg.sender == tapper, "MoneyPoolAdmin::_tapMp: UNAUTHORIZED");
        controller.tapMp(_mpId, _amount, msg.sender);
    }

    /**
        @notice This is how the tapper can propose a reconfiguration to this contract's Money pool.
        @dev The proposed changes will have to be approved by the redeemer.
        @param _target The new Money pool target amount.
        @param _duration The new duration of your Money pool.
        @param _want The new token that your MoneyPool wants.
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
        @return _mpId The ID of the Money pool that was reconfigured.
    */
    function proposeMpReconfiguration(
        uint256 _target,
        uint256 _duration,
        IERC20 _want,
        string memory _title,
        string memory _link,
        uint256 _bias,
        uint256 _o,
        uint256 _b,
        address _bAddress
    ) internal virtual returns (uint256) {
        proposedMpReconfiguration.target = _target;
        proposedMpReconfiguration.duration = _duration;
        proposedMpReconfiguration.want = _want;
        proposedMpReconfiguration.title = _title;
        proposedMpReconfiguration.link = _link;
        proposedMpReconfiguration.bias = _bias;
        proposedMpReconfiguration.o = _o;
        proposedMpReconfiguration.b = _b;
        proposedMpReconfiguration.bAddress = _bAddress;
        proposalDeadline = block.timestamp.add(25920);
    }

    /** 
        @notice Allows the contract owner to approve a proposed Money pool reconfiguration
        @dev The changes will take effect after your active Money pool expires.
        You may way to override this to create new permissions around who gets to decide
        the new Money pool parameters.
        @return _mpId The ID of the reconfigured Money pool.
    */
    function approveMpReconfiguration() external returns (uint256) {
        require(
            proposalDeadline > block.timestamp,
            "Admin::approveMpReconfiguration: NO_ACTIVE_PROPOSAL"
        );

        // Increse the allowance so that Fountain can transfer excess want tokens from this contract's wallet into a MoneyPool.
        proposedMpReconfiguration.want.safeApprove(
            address(controller),
            100000000000000E18
        );

        proposalDeadline = 0;

        return
            controller.configureMp(
                proposedMpReconfiguration.target,
                proposedMpReconfiguration.duration,
                proposedMpReconfiguration.want,
                proposedMpReconfiguration.title,
                proposedMpReconfiguration.link,
                proposedMpReconfiguration.bias,
                proposedMpReconfiguration.o,
                proposedMpReconfiguration.b,
                proposedMpReconfiguration.bAddress
            );
    }

    /** 
      @notice Allows the redeemer to redeem tickets that have been transfered to this contract.
      @param _issuer The issuer who's tickets are being redeemed.
      @param _amount The amount being redeemed.
      @param _minSwappedAmount The minimum amount of this contract's latest `want` token that should be 
      swapped to from the redeemed reward.
    */
    function redeemTickets(
        address _issuer,
        uint256 _amount,
        uint256 _minSwappedAmount
    ) external {
        IERC20 _rewardToken =
            controller.redeem(_issuer, _amount, address(this));

        MoneyPool.Data memory _mp =
            controller.mpStore().getCurrentMp(address(this));

        require(
            _rewardToken.approve(address(router), _amount),
            "MoneyPoolAdmin::redeemTickets: APPROVE_FAILED."
        );

        address[] memory path = new address[](2);
        path[0] = address(_rewardToken);
        path[1] = router.WETH();
        path[2] = address(_mp.want);
        uint256[] memory _amounts =
            router.swapExactTokensForTokens(
                _amount,
                _minSwappedAmount,
                path,
                address(this),
                block.timestamp
            );

        controller.sustainOwner(
            address(this),
            _amounts[2],
            _mp.want,
            address(this)
        );
    }

    /** 
      @notice Sets the address that can tap from this Money pool and propose Money pool reconfigurations.
      @param _newTapper The new address.
    */
    function setTapper(address _newTapper) external {
        require(
            msg.sender == redeemer,
            "MoneyPoolAdmin::setTapper: UNAUTHORIZED"
        );
        tapper = _newTapper;
    }
}
