// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./Math.sol";

/// @notice Logic to manipulate MoneyPool data.
library MoneyPool {
    using SafeMath for uint256;

    /// @notice Possible states that a Money pool may be in
    /// @dev Money pool's are immutable once the Money pool is active.
    enum State {Standby, Active, Redistributing}

    /// @notice The Money pool structure represents a project stewarded by an address, and accounts for which addresses have helped sustain the project.
    struct Data {
        // A unique number that's incremented for each new Money pool, starting with 1.
        uint256 number;
        // The number of the owner's Money pool that came before this one.
        uint256 previous;
        // The title of the Money pool.
        string title;
        // A link that points to a justification for these parameters.
        string link;
        // The address who defined this Money pool and who has access to its sustainments.
        address owner;
        // The token that this Money pool can be funded with.
        IERC20 want;
        // The amount that represents sustainability for this Money pool.
        uint256 target;
        // The running amount that's been contributed to sustaining this Money pool.
        uint256 total;
        // The time when this Money pool will become active.
        uint256 start;
        // The number of seconds until this Money pool's surplus is redistributed.
        uint256 duration;
        // The amount of available funds that have been tapped by the owner.
        uint256 tapped;
        // The timestamp when the Money pool was last configured.
        uint256 lastConfigured;
    }

    // --- internal transactions --- //

    /** 
        @notice Initializes a Money pool's parameters.
        @param self The Money pool to initialize.
        @param _owner The owner of the Money pool.
        @param _start The start time of the Money pool.
        @param _number The number of the Money pool.
        @param _previous The number of the owner's previous Money pool.
    */
    function _init(
        Data storage self,
        address _owner,
        uint256 _start,
        uint256 _number,
        uint256 _previous
    ) internal {
        self.number = _number;
        self.owner = _owner;
        self.start = _start;
        self.previous = _previous;
        self.total = 0;
        self.tapped = 0;
    }

    /** 
        @dev Configures the sustainability target and duration of the sender's current Money pool if it hasn't yet received sustainments, or
        sets the properties of the Money pool that will take effect once the current Money pool expires.
        @param self The Money pool to configure.
        @param _title The title of the Money pool.
        @param _link A link to associate with the Money pool.
        @param _target The sustainability target to set.
        @param _duration The duration to set, measured in seconds.
        @param _want The token that the Money pool wants.
        @param _start The new start time.
    */
    function _configure(
        Data storage self,
        string memory _title,
        string memory _link,
        uint256 _target,
        uint256 _duration,
        IERC20 _want,
        uint256 _start
    ) internal {
        self.title = _title;
        self.link = _link;
        self.target = _target;
        self.duration = _duration;
        self.want = _want;
        self.lastConfigured = block.timestamp;
        self.start = _start;
    }

    /** 
        @notice Contribute a specified amount to the sustainability of the specified address's active Money pool.
        If the amount results in surplus, redistribute the surplus proportionally to sustainers of the Money pool.
        @param self The Money pool to sustain.
        @param _amount Amount of sustainment.
    */
    function _add(Data storage self, uint256 _amount) internal {
        // Increment the total amount contributed to the sustainment of the Money pool.
        self.total = self.total.add(_amount);
    }

    /** 
        @dev Increase the amount that has been tapped by the Money pool's owner.
        @param self The Money pool to tap.
        @param _amount The amount to tap.
    */

    function _tap(Data storage self, uint256 _amount) internal {
        self.tapped = self.tapped.add(_amount);
    }

    /**
        @notice Clones the properties from the base.
        @param self The Money pool to clone onto.
        @param _baseMp The Money pool to clone from.
    */
    function _clone(Data storage self, Data memory _baseMp) internal {
        self.title = _baseMp.title;
        self.link = _baseMp.link;
        self.target = _baseMp.target;
        self.duration = _baseMp.duration;
        self.want = _baseMp.want;
    }

    // --- internal views --- //

    /** 
        @notice The state the Money pool for the given number is in.
        @param self The Money pool to get the state of.
        @return state The state.
    */
    function _state(Data memory self) internal view returns (State) {
        if (_hasExpired(self)) return State.Redistributing;
        if (_hasStarted(self) && self.total > 0) return State.Active;
        return State.Standby;
    }

    /** 
        @notice Returns the amount available for the given Money pool's owner to tap in to.
        @param self The Money pool to make the calculation for.
        @return The resulting amount.
    */
    function _tappableAmount(Data storage self)
        internal
        view
        returns (uint256)
    {
        return Math.min(self.target, self.total).sub(self.tapped);
    }

    /** 
        @notice Returns the date that is the nearest multiple of duration from oldEnd.
        @return start The date.
    */
    function _determineNextStart(Data memory self)
        internal
        view
        returns (uint256)
    {
        uint256 _end = self.start.add(self.duration);
        // Use the old end if the current time is still within the duration.
        if (_end.add(self.duration) > block.timestamp) return _end;
        // Otherwise, use the closest multiple of the duration from the old end.
        uint256 _distanceToStart =
            (block.timestamp.sub(_end)).mod(self.duration);
        return block.timestamp.sub(_distanceToStart);
    }

    // --- private views --- //

    /** 
        @notice Check to see if the given Money pool has started.
        @param self The Money pool to check.
        @return hasStarted The boolean result.
    */
    function _hasStarted(Data memory self) private view returns (bool) {
        return block.timestamp >= self.start;
    }

    /** 
        @notice Check to see if the given MoneyPool has expired.
        @param self The Money pool to check.
        @return hasExpired The boolean result.
    */
    function _hasExpired(Data memory self) private view returns (bool) {
        return block.timestamp > self.start.add(self.duration);
    }
}
