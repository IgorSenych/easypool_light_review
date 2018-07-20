pragma solidity 0.4.24;

import "./common/erc/ERC223Receiver.sol";
import "./libs/PoolLibrary.sol";
import "./zeppelin/Math.sol";


/**
 * @title EasyPool
 * @dev ...
 */
contract EasyPool is ERC223Receiver {
    using PoolLib for PoolLib.Pool;
    PoolLib.Pool pool;    

    /**
     * @dev Fallback.
     */
    function() external payable {
        pool.acceptRefundTransfer();
    }

    /**
     * @dev Constructor.
     */
    constructor(        
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
    ) public {
        pool.init(
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
    }

    // TODO:
    // add forwardTransaction(..)

    function setGroupSettings(                
        uint groupIndex,
        uint maxContBalance,
        uint minContribution,
        uint maxContribution,
        uint ctorFeePerEther,         
        bool isRestricted
    ) external {
        pool.setGroupSettings(                
            groupIndex,
            maxContBalance,
            minContribution,
            maxContribution,
            ctorFeePerEther,         
            isRestricted
        );
    }

    function cancel() external {
        pool.cancel();
    }

    function deposit(uint groupIndex) external {
        pool.deposit(groupIndex);
    }    

    function modifyWhitelist(uint groupIndex, address[] include, address[] exclude) external {
        pool.modifyWhitelist(groupIndex, include, exclude);
    }            

    function payToPresale(address presaleAddress, uint minPoolBalance, bool feeToToken, bytes data) external {
        pool.payToPresale(presaleAddress, minPoolBalance, feeToToken, data);
    }

    function lockPresaleAddress(address presaleAddress) external {
        pool.lockPresaleAddress(presaleAddress);
    }

    function confirmTokenAddress(address tokenAddress) external {
        pool.confirmTokenAddress(tokenAddress);
    }

    function setRefundAddress(address refundAddress) external {
        pool.setRefundAddress(refundAddress);
    }    

    function withdrawAmount(uint amount, uint groupIndex) external {
        pool.withdrawAmount(amount, groupIndex);
    }    

    function withdrawAll() external {
        pool.withdrawAll();
    }    

    function tokenFallback(address from, uint value, bytes data) public {
        pool.tokenFallback(from, value, data);
    }


    // ################################################# //
    //                        VIEW                       //
    // ################################################# //

    /**
     * @dev ...
     */
    function getPoolDetails() 
        external view 
        returns(
            uint libVersion,
            uint groupsCount,
            uint currentState,
            uint svcFeePerEther,
            bool feeToTokenMode,
            address refundAddress,
            address presaleAddress,
            address feeToTokenAddress,
            address[] tokenAddresses,
            address[] participants,
            address[] admins
        ) 
    {
        return pool.getPoolDetails();
    }

    /**
     * @dev ...
     */
    function getParticipantDetails(address partAddress)
        external view 
        returns (
            uint[] contribution,
            uint[] remaining,
            bool[] whitelist,
            bool isAdmin,
            bool exists
        )     
    {
        return pool.getParticipantDetails(partAddress);
    }

    /**
     * @dev ...
     */
    function getGroupDetails(uint groupIndex)
        external view 
        returns (
            uint contributionBalance,
            uint remainingBalance,
            uint maxContBalance,
            uint minContribution,                 
            uint maxContribution,
            uint ctorFeePerEther,
            bool isRestricted,
            bool exists
        ) 
    {
        return pool.getGroupDetails(groupIndex);
    }    

    /**
     * @dev ...
     */
    function getLibVersion() external pure returns(uint version) {
        version = PoolLib.version();
    }

    // ################################################# //
    //                       EVENTS                      //
    // ################################################# //

    event StateChanged(
        uint fromState,
        uint toState
    ); 

    event AdminAdded(
        address adminAddress
    );

    event WhitelistEnabled(
        uint groupIndex
    );

    event PresaleAddressLocked(
        address presaleAddress
    );  

    event RefundAddressChanged(
        address refundAddress
    );    

    event FeesDistributed(
        uint creatorFeeAmount,
        uint serviceFeeAmount
    );

    event IncludedInWhitelist(
        address participantAddress,
        uint groupIndex
    );

    event ExcludedFromWhitelist(
        address participantAddress,
        uint groupIndex
    );  

    event FeeServiceAttached(
        address serviceAddress,
        uint feePerEther
    );    

    event TokenAddressConfirmed(
        address tokenAddress,
        uint tokenBalance
    ); 

    event RefundReceived(
        address senderAddress,
        uint etherAmount
    );    
 
    event Contribution(
        address participantAddress,
        uint groupIndex,
        uint etherAmount,
        uint participantContribution,
        uint groupContribution        
    );

    event Withdrawal(
        address participantAddress,
        uint groupIndex,
        uint etherAmount,
        uint participantContribution,
        uint participantRemaining,        
        uint groupContribution,
        uint groupRemaining
    );

    event TokenWithdrawal(
        address tokenAddress,
        address participantAddress,
        uint poolTokenBalance,
        uint tokenAmount,
        bool succeeded    
    );   

    event RefundWithdrawal(
        address participantAddress,
        uint contractBalance,
        uint poolRemaining,
        uint etherAmount
    );  

    event ContributionAdjusted(
        address participantAddress,
        uint participantContribution,
        uint participantRemaining,
        uint groupContribution,
        uint groupRemaining,
        uint groupIndex
    );
  
    event GroupSettingsChanged(
        uint index,
        uint maxBalance,                               
        uint minContribution,
        uint maxContribution,                        
        uint ctorFeePerEther,
        bool isRestricted                            
    );       

    event AddressTransfer(
        address destinationAddress,
        uint etherValue
    );

    event AddressCall(
        address destinationAddress,
        uint etherAmount,
        uint gasAmount,
        bytes data      
    );   

    event TransactionForwarded(
        address destinationAddress,
        uint etherAmount,
        uint gasAmount,
        bytes data
    );

    event ERC223Fallback(
        address tokenAddress,
        address senderAddress,
        uint tokenAmount,
        bytes data
    );    
}