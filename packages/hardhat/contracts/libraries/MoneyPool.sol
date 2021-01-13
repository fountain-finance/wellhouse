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
        uint256 id;
        // The address who defined this Money pool and who has access to its sustainments.
        address owner;
        // The number of the owner's Money pool that came before this one.
        uint256 previous;
        // The title of the Money pool.
        string title;
        // A link that points to a justification for these parameters.
        string link;
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
        // The percentage of overflow to reserve for the owner once the Money pool has expired.
        uint256 o;
        // The percentage of overflow to reserve for a specified beneficiary once the Money pool has expired.
        uint256 b;
        // The specified beneficiary.
        address bAddress;
        // If the reserved tickets have been minted.
        bool hasMintedReserves;
        // A number determining the amount of redistribution shares this Money pool will issue to each sustainer.
        uint256 weight;
        // A number indicating how much more weight to give a Money pool compared to its predecessor.
        uint256 bias;
    }

    // --- internal transactions --- //

    /**
        @notice Clones the properties from the base.
        @dev Assumes the base is the Money pool that directly preceeded self.
        @param self The Money pool to clone onto.
        @param _baseMp The Money pool to clone from.
    */
    function _basedOn(Data storage self, Data memory _baseMp) internal {
        self.title = _baseMp.title;
        self.link = _baseMp.link;
        self.target = _baseMp.target;
        self.duration = _baseMp.duration;
        self.want = _baseMp.want;
        self.bias = _baseMp.bias;
        self.weight = _derivedWeight(_baseMp);
        self.o = _baseMp.o;
        self.b = _baseMp.b;
        self.bAddress = _baseMp.bAddress;
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

    /** 
        @notice A view of the Money pool that would be created after this one if the owner doesn't make a reconfiguration.
        @return _mp The next Money pool, with an ID set to 0.
    */
    function _nextUp(Data memory self) internal view returns (Data memory _mp) {
        return
            Data(
                0,
                self.owner,
                self.id,
                self.title,
                self.link,
                self.want,
                self.target,
                0,
                _determineNextStart(self),
                self.duration,
                0,
                self.o,
                self.b,
                self.bAddress,
                false,
                self.weight,
                self.bias
            );
    }

    /** 
        @notice Returns the percentage of overflow to allocate to sustainers.
        @return _percentage The percentage.
    */
    function _s(Data memory self) internal pure returns (uint256) {
        return uint256(100).sub(self.o).sub(self.b);
    }

    /** 
        @notice The weight derived from the current weight and the bias.
        @return _weight The new weight.
    */
    function _derivedWeight(Data memory self) internal pure returns (uint256) {
        return self.weight.mul(self.bias).div(100);
    }

    /** 
        @notice Returns the amount available for the given Money pool's owner to tap in to.
        @param self The Money pool to make the calculation for.
        @return The resulting amount.
    */
    function _tappableAmount(Data memory self) internal pure returns (uint256) {
        return Math.min(self.target, self.total).sub(self.tapped);
    }

    /** 
        @notice The weight that a certain amount carries in this Money pool.
        @param self The Money pool to get the weight from.
        @param _amount The amount to get the weight of.
        @return state The weighted amount.
    */
    function _weighted(Data memory self, uint256 _amount)
        internal
        pure
        returns (uint256)
    {
        return self.weight.mul(_amount).div(self.target).mul(_s(self)).div(100);
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
