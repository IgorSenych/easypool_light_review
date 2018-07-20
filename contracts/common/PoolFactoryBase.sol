pragma solidity 0.4.24;


/**
 * @title PoolFactoryBase
 * @dev ...
 */
contract PoolFactoryBase {
    function deploy
    (
        uint maxBalance,
        uint minContribution,
        uint maxContribution,
        uint feePerEther,
        bool restricted,
        address creator,
        address presale,
        address feeManager,
        address[] whitelist,
        address[] adminis
    ) 
        external 
        returns (address poolAddress, uint poolVersion);

}