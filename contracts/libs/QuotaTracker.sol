pragma solidity 0.4.24;

import "./Fraction.sol";
import "../zeppelin/SafeMath.sol";


/**
 * @title QuotaTracker
 * @dev ...
 */
library QuotaTracker {
    using Fraction for uint[2];    

    struct Data {
        mapping (address => uint) claimedBy;
        uint totalClaimed;
    }

    /**     
     * @dev ...
     */
    function claimShare(Data storage self, address addr, uint currentBalance, uint[2] fraction) internal returns (uint) {
        uint share = fraction.shareOf(currentBalance + self.totalClaimed);
        uint claimed = self.claimedBy[addr];
        assert(claimed <= share);

        uint diff = share - claimed;
        self.claimedBy[addr] += diff;
        self.totalClaimed += diff;

        return diff;
    }

    /**     
     * @dev ...
     */
    function undoClaim(Data storage self, address addr, uint amount) internal returns (uint) {
        assert(amount <= self.claimedBy[addr]);

        self.claimedBy[addr] -= amount;
        self.totalClaimed -= amount;
    }
}