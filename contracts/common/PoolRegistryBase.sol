pragma solidity 0.4.24;


/**
 * @title PoolRegistryBase
 * @dev ...
 */
contract PoolRegistryBase {
    /**
     * @dev ...
     */
    function register(
        address creatorAddress,
        address poolAddress,
        uint poolVersion,
        uint code
    ) 
        external;
}