pragma solidity 0.4.24;


/**
 * @title Fraction
 * @dev ...
 */
library Fraction {
    function shareOf(uint[2] fraction, uint total) internal pure returns (uint) {
        return (total * fraction[0]) / fraction[1];
    }
}