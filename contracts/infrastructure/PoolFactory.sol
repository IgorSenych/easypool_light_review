pragma solidity 0.4.24;

import "../EasyPool.sol";
import "../zeppelin/NoEther.sol";
import "../common/Restricted.sol";
import "../common/PoolFactoryBase.sol";


/**
 * @title PoolFactory
 * @dev ...
 */
contract PoolFactory is PoolFactoryBase, HasNoEther, Restricted {

    function deploy(
        uint maxContBalance,
        uint minContribution,
        uint maxContribution,
        uint ctorFeePerEther,
        bool isRestricted,                
        address creatorAddress,
        address presaleAddress,        
        address feeServiceAddr,
        address[] whitelist,
        address[] admins
    ) 
        external
        onlyOperator
        returns (address poolAddress, uint poolVersion) 
    {
        EasyPool pool = new EasyPool(
            maxContBalance,
            minContribution,
            maxContribution,
            ctorFeePerEther,
            isRestricted,                
            creatorAddress,
            presaleAddress,        
            feeServiceAddr,
            whitelist,
            admins
        );
                
        poolAddress = address(pool);        
        poolVersion = pool.getLibVersion();
    }
}