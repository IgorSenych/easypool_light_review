pragma solidity 0.4.24;

import "../zeppelin/NoEther.sol";
import "../common/Restricted.sol";
import "../common/PoolRegistryBase.sol";


/**
 * @title PoolRegistry
 * @dev The purpose of PoolRegistry contract is to keep track of all created pool contracts. 
 */
contract PoolRegistry is PoolRegistryBase, HasNoEther, Restricted {

    event PoolRegistered(
        address indexed creatorAddress,
        uint indexed poolVersion,
        uint indexed code,
        address poolAddress              
    );

    /**
     * Register contract (i.e. log an event with all creation details).
     */
    function register(
        address creatorAddress,
        address poolAddress,
        uint poolVersion,
        uint code
    ) 
        external
        onlyOperator
    {
        require(
            creatorAddress != address(0) &&
            poolAddress != creatorAddress
        );        
        
        emit PoolRegistered(
            creatorAddress,
            poolVersion,
            code,
            poolAddress
        );
    }
}