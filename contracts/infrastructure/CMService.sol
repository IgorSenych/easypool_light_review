pragma solidity 0.4.24;

import "../zeppelin/NoEther.sol";
import "../zeppelin/Pausable.sol";
import "../common/PoolFactoryBase.sol";
import "../common/PoolRegistryBase.sol";


/**
* @title CMService
* @dev ...
*/
contract CMService is HasNoEther, Pausable  {    

    event FeeServiceChanged(address newFeeService);
    event PoolFactoryChanged(address newPoolFactory);
    event PoolRegistryChanged(address newPoolRegistry);        

    address public feeService;      
    PoolFactoryBase public poolFactory;
    PoolRegistryBase public poolRegistry;    

    /**
     * @dev ...
     */
    function newPoolDeploy(
        uint code,        
        uint maxContBalance,
        uint minContribution,
        uint maxContribution,
        uint ctorFeePerEther,
        bool isRestricted,                        
        address presaleAddr,                
        address[] whitelist,
        address[] admins 
    ) 
        external 
        whenNotPaused
    {
        require(feeService != address(0));

        uint poolVersion;
        address poolAddress;        
        (poolAddress, poolVersion) = poolFactory.deploy(
            maxContBalance,
            minContribution,
            maxContribution,
            ctorFeePerEther,
            isRestricted,
            msg.sender,
            presaleAddr,
            feeService,
            whitelist,
            admins
        );     

        poolRegistry.register(
            msg.sender,
            poolAddress,
            poolVersion,
            0 //TODO: Stack too deep: code     
        );
    }

    /**
     * @dev ...
     */
    function setFeeService(address newFeeService) external onlyOwner {
        feeService = newFeeService;
        emit FeeServiceChanged(newFeeService);
    }

    /**
     * @dev ...
     */
    function setPoolFactory(address newPoolFactory) external onlyOwner {
        poolFactory = PoolFactoryBase(newPoolFactory);
        emit PoolFactoryChanged(newPoolFactory);
    }

    /**
     * @dev ...
     */
    function setPoolRegistry(address newPoolRegistry) external onlyOwner {
        poolRegistry = PoolRegistryBase(newPoolRegistry);
        emit PoolRegistryChanged(newPoolRegistry);
    }
}