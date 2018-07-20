pragma solidity 0.4.24;


/**
 * @title Math
 * @dev Assorted math operations.
 */
library Math {
     
    /**
     * @dev Returns the smaller of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the larger of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }
}
