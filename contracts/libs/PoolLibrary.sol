pragma solidity 0.4.24;

import "./QuotaTracker.sol";
import "../zeppelin/Math.sol";
import "../zeppelin/SafeMath.sol";
import "../common/erc/ERC20Basic.sol";
import "../common/FeeServiceBase.sol";

    /**
     * @title PoolLib
     * @dev ...
     */
library PoolLib {    
    using QuotaTracker for QuotaTracker.Data;
    using SafeMath for uint;    

    /**
     * @dev Pool possible states.
     */
    enum State {
        Open,
        PaidToPresale,
        Distribution,        
        FullRefund,
        Canceled
    }

    /**
     * @dev Participation groups settings & details.     
     */
    struct Group {
        // details
        uint contribution;            
        uint remaining;   
        // settings
        uint maxContBalance;
        uint minContribution; 
        uint maxContribution;        
        uint ctorFeePerEther;                                                
        bool isRestricted;
        bool exists;
    }    

    /**
     * @dev Pool participant details.
     */
    struct Participant {
        // array index == grop index
        uint[8] contribution;
        uint[8] remaining;
        bool[8] whitelist;  
        bool isAdmin;
        bool exists;
    }

    /**
     * @dev Pool participant details.
     */
    struct Pool {               
        State state;
        uint svcFeePerEther;        
        address refundAddress;
        address presaleAddress;
        address feeToTokenAddress;
        FeeServiceBase feeService;
        bool feeToTokenMode;
                  
        address[] admins;
        address[] participants; 
        address[] tokenAddresses;   

        Group[8] groups;         
        mapping(address => Participant) participantToData;
        mapping(address => QuotaTracker.Data) tokenDeposits;        
        QuotaTracker.Data refundTracker;
    }
        

    // ################################################# //
    //                    CONSTRUCTOR                    //
    // ################################################# //                

    /**
     * @dev ...
     */
    function init(
        Pool storage pool,           
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
        public 
    {        
        // lock presale addr
        if(presaleAddress != address(0)) {
            pool.presaleAddress = presaleAddress;
            emit PresaleAddressLocked(presaleAddress);
        }
        
        // get service fee per ether
        pool.feeService = FeeServiceBase(feeServiceAddr);
        pool.svcFeePerEther = pool.feeService.getFeePerEther();
        emit FeeServiceAttached(
            feeServiceAddr,
            pool.svcFeePerEther
        );  

        // set administrators list
        addAdmin(pool, creatorAddress);
        for(uint i = 0; i < admins.length; i++) {
            addAdmin(pool, admins[i]);           
        }  

        // set default group settings
        setGroupSettings_TempPrivateSolution(
            pool,
            0,
            maxContBalance,
            minContribution,
            maxContribution,
            ctorFeePerEther,
            isRestricted            
        );

        // set whitelist
        if(whitelist.length > 0) {
            require(isRestricted);
            modifyWhitelist(pool, 0, whitelist, new address[](0));
        }
    }


    // ################################################# //
    //                     MODIFIERS                     //
    // ################################################# //                

    /**
     * @dev Throw if not owner.
     */
    modifier onlyAdmin(Pool storage pool) {
        require(pool.participantToData[msg.sender].isAdmin);        
        _;
    }

    /**
     * @dev Throw if wrong state.
     */
    modifier onlyInState(Pool storage pool, State state) {
        require(pool.state == state);
        _;
    }      

    /**
     * @dev Throw if wrong state.
     */
    modifier onlyInStates2(Pool storage pool, State state1, State state2) {
        require(pool.state == state1 || pool.state == state2);
        _;
    }  

    /**
     * @dev Throw if wrong state.
     */
    modifier onlyInStates3(Pool storage pool, State state1, State state2, State state3) {
        require(pool.state == state1 || pool.state == state2 || pool.state == state3);
        _;
    }      


    // ################################################# //
    //                      PUBLIC                       //
    // ################################################# //

    /**
     * @dev Add or update participation settings (public).
     */
    function setGroupSettings(
        Pool storage pool,        
        uint idx,
        uint maxContBalance,
        uint minContribution,
        uint maxContribution,
        uint ctorFeePerEther,         
        bool isRestricted
    )
        public      
        onlyAdmin(pool) 
        onlyInState(pool, State.Open) 
    {
        setGroupSettings_TempPrivateSolution(
            pool,        
            idx,
            maxContBalance,
            minContribution,
            maxContribution,
            ctorFeePerEther,
            isRestricted
        );
    }

    /**
     * @dev Add or update participation settings (private).
     */
    function setGroupSettings_TempPrivateSolution(
        Pool storage pool,        
        uint idx,
        uint maxContBalance,
        uint minContribution,
        uint maxContribution,
        uint ctorFeePerEther,         
        bool isRestricted
    )
        private              
    {
        require(pool.groups.length > idx);
        Group storage group = pool.groups[idx];
        bool exists = group.exists;

        if(!exists) {            
            require(idx == 0 || pool.groups[idx - 1].exists);            
            group.exists = true;
        }
        
        validateGroupSettings(
            maxContBalance, 
            minContribution, 
            maxContribution
        );        
        
        if(group.maxContBalance != maxContBalance) {
            group.maxContBalance = maxContBalance;  
        }          
        
        if(group.minContribution != minContribution) {
            group.minContribution = minContribution;
        }

        if(group.maxContribution != maxContribution) {
            group.maxContribution = maxContribution;
        }
        
        if(group.ctorFeePerEther >= ctorFeePerEther) {
            group.ctorFeePerEther = ctorFeePerEther;
        }
        
        if(group.isRestricted != isRestricted) {
            group.isRestricted = isRestricted;  
        }      

        emit GroupSettingsChanged(
            idx,
            maxContBalance,
            minContribution,
            maxContribution,
            ctorFeePerEther,
            isRestricted
        );                 
        
        if(exists) {
            rebalance(pool, idx);
        }
    }

    /**
     * @dev Make contribution.
     */
    function deposit(Pool storage pool, uint idx)
        public        
        onlyInState(pool, State.Open)  
    {
        require(
            msg.value > 0 &&
            pool.groups.length > idx &&
            pool.groups[idx].exists
        );

        Group storage group = pool.groups[idx];   
        Participant storage participant = pool.participantToData[msg.sender];              
        require(!group.isRestricted || participant.whitelist[idx] || participant.isAdmin);
                    
        uint oldRemaining = participant.remaining[idx];
        uint oldContribution = participant.contribution[idx];                

        uint newRemaining;
        uint newContribution;        
        (newContribution, newRemaining) = calcContribution(
            group.minContribution,
            group.maxContribution,
            group.maxContBalance,
            group.contribution,            
            oldContribution + oldRemaining + msg.value,
            !group.isRestricted || participant.whitelist[idx],
            participant.isAdmin
        );
        require(newRemaining == 0);
        
        if (!participant.exists) {
            participant.exists = true;   
            pool.participants.push(msg.sender);
        }        

        if(!participant.whitelist[idx]) {
            participant.whitelist[idx] = true;         
        }

        group.contribution = group.contribution - oldContribution + newContribution;
        group.remaining = group.remaining - oldRemaining + newRemaining;
        participant.contribution[idx] = newContribution;
        participant.remaining[idx] = newRemaining;

        emit Contribution(
            msg.sender,
            idx,
            msg.value,
            newContribution,
            group.contribution
        );        
    }

    /**
     * @dev Modify group witelist.
     */
    function modifyWhitelist(Pool storage pool, uint idx, address[] include, address[] exclude)
        public 
        onlyInState(pool, State.Open)
    {
        require(include.length > 0 || exclude.length > 0);
        require(pool.groups.length > idx && pool.groups[idx].exists);

        Group storage group = pool.groups[idx];                                        
        Participant storage participant;                        
        uint i;

        if(!group.isRestricted) {            
            group.isRestricted = true;
            emit WhitelistEnabled(idx);
        }
        
        // exclude
        for(i = 0; i < exclude.length; i++) {
            participant = pool.participantToData[exclude[i]];            
            if(participant.whitelist[idx]) {
                participant.whitelist[idx] = false;
                emit ExcludedFromWhitelist(
                    exclude[i],
                    idx
                );                
            }
        }

        // include
        for(i = 0; i < include.length; i++) {
            participant = pool.participantToData[include[i]];          
            if(!participant.whitelist[idx]) {                
                if (!participant.exists) {
                    participant.exists = true;
                    pool.participants.push(include[i]);                    
                }                        
                participant.whitelist[idx] = true;               
                emit IncludedInWhitelist(
                    include[i],
                    idx
                );
            }                
        }

        // rebalance
        rebalance(pool, idx);
    }

    /**
     * @dev Withdraw pool contribution.
     */
    function payToPresale(
        Pool storage pool,
        address presaleAddress,
        uint minPoolBalance,
        bool feeToToken,        
        bytes data
    )
        public
        onlyAdmin(pool) 
        onlyInState(pool, State.Open) 
    {
        require(presaleAddress != address(0));
        
        if(pool.presaleAddress == address(0)) {            
            pool.presaleAddress = presaleAddress;      
            emit PresaleAddressLocked(presaleAddress);      
        } else {
            require(pool.presaleAddress == presaleAddress);
        }
        
        uint ctorFee;
        uint poolRemaining;
        uint poolContribution;                
        (poolContribution, poolRemaining, ctorFee) = getPoolSummary(pool);
        require(poolContribution > 0 && poolContribution >= minPoolBalance);                                   

        if(feeToToken) {
            pool.feeToTokenMode = true;            
            pool.feeToTokenAddress = msg.sender;
            ctorFee = 0;
        }

        uint svcFee = calcFee(poolContribution, pool.svcFeePerEther);

        changeState(pool, State.PaidToPresale);
        addressCall(
            pool.presaleAddress,             
            poolContribution.sub(ctorFee).sub(svcFee),            
            data
        );        
    }   

    /**
     * @dev Confirm/add new token address.
     */
    function confirmTokenAddress(Pool storage pool, address tokenAddress)
        public
        onlyAdmin(pool)
        onlyInStates2(pool, State.PaidToPresale, State.Distribution)         
    {
        require(
            tokenAddress != address(0) &&
            pool.tokenAddresses.length <= 4 &&
            !contains(pool.tokenAddresses, tokenAddress)
        );

        ERC20Basic ERC20 = ERC20Basic(tokenAddress);
        uint balance = ERC20.balanceOf(address(this));
        require(balance > 0);     

        if(pool.state == State.PaidToPresale) {
            changeState(pool, State.Distribution);            
            sendFees(pool);
        } 
                        
        pool.tokenAddresses.push(tokenAddress);        
        emit TokenAddressConfirmed(
            tokenAddress,
            balance
        );
    }

    /**
     * @dev Set refund sender address.
     */
    function setRefundAddress(Pool storage pool, address refundAddress)
        public
        onlyAdmin(pool)
        onlyInStates3(pool, State.PaidToPresale, State.Distribution, State.FullRefund)
    {
        require(
            refundAddress != address(0) &&
            pool.refundAddress != refundAddress
        );

        pool.refundAddress = refundAddress;
        emit RefundAddressChanged(refundAddress);

        if(pool.state == State.PaidToPresale) {
            changeState(pool, State.FullRefund);
        }
    }

    /**
     * @dev Lock presale address.
     */
    function lockPresaleAddress(Pool storage pool, address presaleAddress)
        public 
        onlyAdmin(pool) 
        onlyInState(pool, State.Open) 
    {
        require(
            presaleAddress != address(0) &&
            pool.presaleAddress == address(0)
        );
        pool.presaleAddress = presaleAddress;
        emit PresaleAddressLocked(presaleAddress);
    }  

    /**
     * @dev ERC223 fallback.
     */
    function tokenFallback(Pool storage pool, address from, uint value, bytes data)
        public 
        onlyInStates2(pool, State.PaidToPresale, State.Distribution)
    {
        emit ERC223Fallback(
            msg.sender,
            from,
            value,
            data
        );
    }

    /**
     * @dev Make sure we can accept refund transfer.
     */
    function acceptRefundTransfer(Pool storage pool)
        public 
        onlyInStates2(pool, State.Distribution, State.FullRefund)  
    {
        require(msg.sender == pool.refundAddress);
        emit RefundReceived(msg.sender, msg.value);
    }

    /**
     * @dev Cancel pool.
     */
    function cancel(Pool storage pool)
        public
        onlyAdmin(pool) 
        onlyInState(pool, State.Open)
    {
        changeState(pool, State.Canceled);
    }

    /**
     * @dev Library version.
     */
    function version() public pure returns (uint) {
        // major: 1
        // minor: 000
        // revision: 000
        return 1000000;        
    } 


    // ################################################# //
    //                     WITHDRAW                      //
    // ################################################# // 

    /**
     * @dev Withdraw from group.
     */     
    function withdrawAmount(Pool storage pool, uint amount, uint idx)
        public
        onlyInState(pool, State.Open)
    {
        Participant storage participant = pool.participantToData[msg.sender];                
        uint remaining = participant.remaining[idx];                
        uint newAmount;        

        if(amount == 0) {
            newAmount = participant.contribution[idx] + remaining;
        } else {
            require(
                amount >= remaining &&
                amount <= (participant.contribution[idx] + remaining)
            );
            newAmount = amount;
        }

        require(newAmount > 0);
        participant.remaining[idx] = 0;                                 
        Group storage group = pool.groups[idx];
        group.remaining -= remaining;        

        uint delta = newAmount - remaining;
        if(delta > 0) {
            group.contribution -= delta;
            participant.contribution[idx] -= delta;
            if(!participant.isAdmin) {
                require(participant.contribution[idx] >= group.minContribution);
            }
        }

        emit Withdrawal(
            msg.sender,
            newAmount,
            participant.contribution[idx],
            0,
            group.contribution,
            group.remaining,
            idx
        );
                
        addressTransfer(msg.sender, newAmount);
    } 

    /**
     * @dev Wihdraw all (public).
     */ 
    function withdrawAll(Pool storage pool) public {
        if (pool.state == State.FullRefund || pool.state == State.Distribution) {
            withdrawRefundAndTokens(pool);
            return;
        }

        if(pool.state == State.Canceled || pool.state == State.Open) {
            withdrawAllContribution(pool);
            return;
        }            

        if (pool.state == State.PaidToPresale) {
            withdrawAllRemaining1(pool);
            return;
        } 

        assert(false);
    }

    /**
     * @dev Withdraw contribution + remaining.
     */     
    function withdrawAllContribution(Pool storage pool) private {
        Participant storage participant = pool.participantToData[msg.sender];
        Group storage group;
        uint contribution;  
        uint remaining;
        uint amount;
        uint sum;

        uint length = pool.groups.length;
        for(uint idx = 0; idx < length; idx++) {
            contribution = participant.contribution[idx];
            remaining = participant.remaining[idx];
            sum = contribution + remaining;

            if(sum > 0) {
                amount += sum;
                group = pool.groups[idx];

                if(contribution > 0) {
                    group.contribution -= contribution;
                    participant.contribution[idx] = 0;
                }
                if(remaining > 0) {
                    group.remaining -= remaining;
                    participant.remaining[idx] = 0;
                }
                                       

                emit Withdrawal(
                    msg.sender,
                    idx,
                    sum,
                    0,
                    0,
                    group.contribution,
                    group.remaining                    
                );
            }
        }

        require(amount > 0);        
        addressTransfer(msg.sender, amount);
    }

    /**
     * @dev Wihdraw only remaining (simple version).
     */  
    function withdrawAllRemaining1(Pool storage pool) private {
        Participant storage participant = pool.participantToData[msg.sender];        
        Group storage group;
        uint remaining;
        uint amount;
        
        uint length = pool.groups.length;
        for(uint idx = 0; idx <= length; idx++) {            
            remaining = participant.remaining[idx];                      
            
            if(remaining > 0) {
                amount += remaining;
                group = pool.groups[idx];
                group.remaining -= remaining;        
                participant.remaining[idx] = 0;                                

                emit Withdrawal(
                    msg.sender,
                    idx,
                    remaining,
                    participant.contribution[idx],
                    0,
                    group.contribution,
                    group.remaining
                );
            }
        }

        require(amount > 0);
        addressTransfer(msg.sender, amount);
    }

    /**
     * @dev Wihdraw only remaining (advanced version).
     */  
    function withdrawAllRemaining2(Pool storage pool) 
        private 
        returns(
            uint poolContribution,
            uint poolRemaining,        
            uint poolCtorFee,  
            uint partContribution,              
            uint partRemaining,        
            uint partCtorFee
        ) 
    {
        Participant storage participant = pool.participantToData[msg.sender];
        Group storage group;
        uint remaining;     

        uint length = pool.groups.length;
        for(uint idx = 0; idx <= length; idx++) {
            
            group = pool.groups[idx];
            poolRemaining += group.remaining;
            poolContribution += group.contribution;
            poolCtorFee += calcFee(group.contribution, group.ctorFeePerEther);
            
            remaining = participant.remaining[idx];
            partContribution += participant.contribution[idx];
            partCtorFee += calcFee(participant.contribution[idx], group.ctorFeePerEther);

            if(remaining > 0) {              
                partRemaining += remaining;                            
                group.remaining -= remaining;
                participant.remaining[idx] = 0;  

                emit Withdrawal(
                    msg.sender,
                    idx,
                    remaining,
                    participant.contribution[idx],
                    0,
                    group.contribution,
                    group.remaining                    
                );
            }
        }

        if(partRemaining > 0) {
            addressTransfer(msg.sender, partRemaining);
        }
    }    
    
    /**
     * @dev Withdarw refund share and transfer tokens.
     */  
    function withdrawRefundAndTokens(Pool storage pool) private {
        uint poolContribution;
        uint poolRemaining;
        uint poolCtorFee;
        uint partContribution;
        uint partRemaining;
        uint partCtorFee;
        (poolContribution, poolRemaining, poolCtorFee, partContribution, partRemaining, partCtorFee) = withdrawAllRemaining2(pool);

        if(partContribution > 0) {
            uint netPoolContribution;
            uint netPartContribution;
            (netPoolContribution, netPartContribution) = calcNetContribution(pool, poolContribution, poolCtorFee, partContribution, partCtorFee);
            
            withdrawRefundShare(pool, poolRemaining.sub(partRemaining), netPoolContribution, netPartContribution);
            withdrawTokens(pool, netPartContribution, netPoolContribution);
        }
    }

    /**
     * @dev Withdarw refund share.
     */
    function withdrawRefundShare(
        Pool storage pool, 
        uint poolRemaining,
        uint netPoolContribution, 
        uint netPartContribution
    )
        private 
    {
        if(address(this).balance > poolRemaining) {
            uint amount = pool.refundTracker.claimShare(
                msg.sender, 
                address(this).balance - poolRemaining,
                [netPartContribution, netPoolContribution]
            );

            if(amount > 0) {                                
                emit RefundWithdrawal(
                    msg.sender,
                    address(this).balance,
                    poolRemaining,
                    amount
                );
                addressTransfer(msg.sender, amount);
            }
        }
    }

    /**
     * @dev Transafer tokens.
     */
    function withdrawTokens(
        Pool storage pool,
        // TODO: don't we want this parameter: address participant?
        uint netPoolContribution, 
        uint netPartContribution
    )
        private 
    {        
        bool succeeded;
        uint tokenAmount;
        uint tokenBalance;
        address tokenAddress;
        ERC20Basic tokenContract;
        QuotaTracker.Data storage quotaTracker;
        uint length = pool.tokenAddresses.length;

        for(uint i = 0; i < length; i++) {                
            tokenAddress = pool.tokenAddresses[i];
            tokenContract = ERC20Basic(tokenAddress); 
            tokenBalance = tokenContract.balanceOf(address(this));

            if(tokenBalance > 0) {                                        
                quotaTracker = pool.tokenDeposits[tokenAddress];
                tokenAmount = quotaTracker.claimShare(
                    msg.sender,
                    tokenBalance, 
                    [netPartContribution, netPoolContribution]
                ); 

                if(tokenAmount > 0) {
                    succeeded = tokenContract.transfer(msg.sender, tokenAmount);
                    if (!succeeded) {
                        quotaTracker.undoClaim(msg.sender, tokenAmount);
                    }
                    emit TokenWithdrawal(
                        tokenAddress,
                        msg.sender,
                        tokenBalance,
                        tokenAmount,
                        succeeded
                    );
                }
            }
        } 
    }  


    // ################################################# //
    //                      PRIVATE                      //
    // ################################################# //  

  
    /**
     * @dev ...
     */
    function getPoolCreator(Pool storage pool) private view returns(address) {
        return pool.admins[0];
    }  

    /**
     * @dev Distribute service and creator fees.
     */
    function sendFees(Pool storage pool) private {
        uint ctorFee;
        uint poolRemaining;
        uint poolContribution;
        (poolContribution, poolRemaining, ctorFee) = getPoolSummary(pool);
        if(ctorFee > 0 && !pool.feeToTokenMode) {
            addressTransfer(msg.sender, ctorFee);            
        }
            
        uint svcFee = address(this).balance.sub(poolRemaining);        
        if(svcFee > 0) {
            address creator = getPoolCreator(pool);
            pool.feeService.sendFee.value(svcFee)(creator);
        }

        emit FeesDistributed(
            ctorFee,
            svcFee
        );
    }   

    /**
     * @dev Rebalance group participants.
     */
    function rebalance(Pool storage pool, uint idx) private {
        Group storage group = pool.groups[idx];          
        uint maxContrBalance = group.maxContBalance;  
        uint minContribution = group.minContribution;    
        uint maxContribution = group.maxContribution;            
        bool restricted = group.isRestricted;        
        Participant storage participant;         
        uint groupContribution;
        uint groupRemaining;
        uint contribution;
        uint remaining;     
        uint x = idx;   

        // TODO: Optimize
        //uint count = pool.participants.length;
        for(uint i = 0; i < pool.participants.length; i++) {           
            participant = pool.participantToData[pool.participants[i]];                

            (contribution, remaining) = calcContribution(
                minContribution,
                maxContribution,
                maxContrBalance,
                groupContribution,
                participant.contribution[x]
                    .add(participant.remaining[x]),
                !restricted || participant.whitelist[x],
                participant.isAdmin
            );

            if(contribution != participant.contribution[x]) {
                participant.contribution[x] = contribution;
                participant.remaining[x] = remaining;
            }            
            
            groupContribution += contribution;            
            groupRemaining += remaining;

            emit ContributionAdjusted(
                pool.participants[i], 
                contribution,
                remaining,
                groupContribution,
                groupRemaining,
                x
            );
        }
        
        if(group.contribution != groupContribution) {
            group.contribution = groupContribution;             
            group.remaining = groupRemaining;           
        }  
    } 

    /**
     * @dev Change pool state.
     */
    function changeState(Pool storage pool, State state) private {
        // Don't we want make sure here that state will really changed?
        emit StateChanged(
            uint(pool.state), 
            uint(state)
        );
        pool.state = state;        
    }

    /**
     * @dev Add pool admin.
     */
    function addAdmin(Pool storage pool, address admin) private {
        require(admin != address(0));
        Participant storage participant = pool.participantToData[admin];
        require(!participant.isAdmin);

        participant.exists = true; 
        participant.isAdmin = true;
        pool.participants.push(admin);
        pool.admins.push(admin);             
        
        emit AdminAdded(admin);                  
    }  

    /**
     * @dev Trusted/safe transfer.
     */
    function addressTransfer(address destination, uint etherAmount) private {
        emit AddressTransfer(
            destination,
            etherAmount
        );
        destination.transfer(etherAmount);        
    }

    /**
     * @dev Untrasted call.
     */
    function addressCall(address destination, uint etherAmount, bytes data) private {
        addressCall(destination, 0, etherAmount, data);
    }

    /**
     * @dev Untrasted call.
     */
    function addressCall(address destination, uint gasAmount,  uint etherAmount, bytes data) private {
        emit AddressCall(
            destination,
            etherAmount,
            gasAmount > 0 ? gasAmount : gasleft(),
            data
        );
        require(
            destination.call
            .gas(gasAmount > 0 ? gasAmount : gasleft())
            .value(etherAmount)
            (data)
        );
    }

    /**
     * @dev Calculate pool summaries.
     */
    function getPoolSummary(Pool storage pool) private view returns(uint poolContribution, uint poolRemaining, uint ctorFee) {
        Group storage group;
        uint count = pool.groups.length;
        for(uint i = 0; i < count; i++) {
            group = pool.groups[i];
            if(!group.exists) {
                break;
            }
            
            poolRemaining += group.remaining;
            poolContribution += group.contribution;            
            ctorFee += calcFee(group.contribution, group.ctorFeePerEther);
        }
    }  
  
    /**
     * @dev Validate group settings.
     */
    function validateGroupSettings(uint maxContrBalance, uint minContribution, uint maxContribution) private pure {
        require(
            minContribution <= maxContribution &&
            maxContribution <= maxContrBalance &&
            maxContrBalance <= 1000000 ether
        );
    }   

    /**
     * @dev Calculate contribution based on settings.
     */
    function calcContribution(
        uint minContribution, 
        uint maxContribution,
        uint maxContrBalance, 
        uint curBalance, 
        uint totAmount, 
        bool included, 
        bool admin
    )
        private pure 
        returns(uint contribution, uint remaining)
    {
        if(admin) {    
            remaining = 0;   
            contribution = totAmount;                     
        } else if (!included || totAmount < minContribution) {
            remaining = totAmount;
            contribution = 0;            
        } else {
            contribution = Math.min(maxContribution, totAmount);                        
            contribution = Math.min(maxContrBalance - curBalance, contribution);        
            remaining = totAmount - contribution;        
        }
    }

    /**
     * @dev Fee calculator.
     */
    function calcFee(uint etherAmount, uint feePerEther) private pure returns(uint fee) {
        fee = etherAmount.mul(feePerEther).div(1 ether);
    }

    /**
     * @dev ...
     */
    function contains(address[] storage array, address addr) internal view returns (bool) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == addr) {
                return true;
            }
        }
        return false;
    }    

    /**
     * @dev Calculate net contribution.
     */
    function calcNetContribution(
        Pool storage pool, 
        uint poolContribution, 
        uint poolCtorFee, 
        uint partContribution,         
        uint partCtorFee        
    )
        private view
        returns(uint netPoolContribution, uint netPartContribution) 
    {
        netPoolContribution = poolContribution - poolCtorFee - calcFee(poolContribution, pool.svcFeePerEther);
        netPartContribution = partContribution - partCtorFee - calcFee(partContribution, pool.svcFeePerEther);        

        if(pool.feeToTokenMode) {
            netPoolContribution += poolCtorFee;
            if(pool.feeToTokenAddress == msg.sender) {
                netPartContribution += poolCtorFee;
            }
        }
    }


    // ################################################# //
    //                        VIEW                       //
    // ################################################# //

    /**
     * @dev ...
     */
    function getPoolDetails(Pool storage pool) 
        public view 
        returns (     
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
        libVersion = version();
        currentState = uint(pool.state);
        groupsCount = pool.groups.length;
        svcFeePerEther = pool.svcFeePerEther;
        feeToTokenMode = pool.feeToTokenMode;
        refundAddress = pool.refundAddress;
        presaleAddress = pool.presaleAddress;
        feeToTokenAddress = pool.feeToTokenAddress;
        tokenAddresses = pool.tokenAddresses;
        participants = pool.participants;
        admins = pool.admins;
    }

    /**
     * @dev ...
     */
    function getParticipantDetails(Pool storage pool, address addr)
        public view 
        returns (
            uint[] contribution,
            uint[] remaining,
            bool[] whitelist,
            bool isAdmin,
            bool exists
        ) 
    {
        Participant storage part = pool.participantToData[addr];
        isAdmin = part.isAdmin;                
        exists = part.exists;

        uint length = pool.groups.length;
        contribution = new uint[](length);
        remaining = new uint[](length);
        whitelist = new bool[](length);        

        for(uint i = 0; i < length; i++) {
            contribution[i] = part.contribution[i];
            remaining[i] = part.remaining[i];
            whitelist[i] = part.whitelist[i];
        }                      
    }        

    /**
     * @dev ...
     */
    function getGroupDetails(Pool storage pool, uint idx)
        public view 
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
        Group storage group = pool.groups[idx];                                                
        contributionBalance = group.contribution;
        remainingBalance = group.remaining;
        maxContBalance = group.maxContBalance;
        minContribution = group.minContribution;
        maxContribution = group.maxContribution;
        ctorFeePerEther = group.ctorFeePerEther;
        isRestricted = group.isRestricted;
        exists = group.exists;
    }    


    // ################################################# //
    //                      EVENTS                       //
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


    // /**
    //  * @dev ...
    //  */
    // function withdrawAfterOpen(Pool storage pool) 
    //     public
    //     onlyInStates3(pool, State.PaidToPresale, State.Distribution, State.FullRefund)
    // {
    //     Participant storage participant = pool.participantToData[msg.sender];                        
        
    //     uint poolRemaining;
    //     uint poolContribution;
    //     uint poolCreatorFee;
                
    //     uint partRemaining;
    //     uint partContribution;   
    //     uint partCreatorFee;           
        
    //     uint remaining;
    //     Group storage group;
    //     uint idx = pool.lastGroupIdx;
    //     for(uint i = 0; i <= idx; i++) {
            
    //         group = pool.groups[i];
    //         poolRemaining += group.remaining;
    //         poolContribution += group.contribution;
    //         poolCreatorFee += calcFee(group.contribution, group.feePerEther);
            
    //         remaining = participant.remaining[i];
    //         partContribution += participant.contribution[i];
    //         partCreatorFee += calcFee(participant.contribution[i], group.feePerEther);

    //         if(remaining > 0) {                              
    //             participant.remaining[i] = 0;
    //             group.remaining -= remaining;
    //             partRemaining += remaining;

    //             emit Withdrawal(
    //                 msg.sender,
    //                 remaining,
    //                 participant.contribution[i],
    //                 0,
    //                 group.contribution,
    //                 group.remaining,
    //                 i
    //             );
    //         }
    //     }

    //     uint refundShare;
    //     if(partContribution > 0) {

    //         uint partServiceFee = calcFee(partContribution, pool.svcFeePerEther);            
    //         uint netPartContribution = partContribution - partCreatorFee - partServiceFee;   

    //         uint poolServiceFee = calcFee(poolContribution, pool.svcFeePerEther);         
    //         uint netPoolContribution = poolContribution - poolCreatorFee - poolServiceFee;            

    //         if(pool.feeToToken) {
    //             netPoolContribution += pool.feeToTokenAmount;
    //             if(pool.feeToTokenAddress == msg.sender) {
    //                 netPartContribution += pool.feeToTokenAmount;
    //             }
    //         }
            
    //         // refund            
    //         if(address(this).balance > poolRemaining) {                         
    //             refundShare = pool.refundQuota.claimShare(
    //                 msg.sender, 
    //                 address(this).balance - poolRemaining,
    //                 [netPartContribution, netPoolContribution]
    //             );

    //             emit RefundClaimed(
    //                 msg.sender,
    //                 address(this).balance,
    //                 poolRemaining,
    //                 refundShare
    //             );
    //         }

    //         // tokens
    //         withdrawTokens(pool, msg.sender, netPartContribution, netPoolContribution);
    //     }  

    //     if(refundShare > 0 || partRemaining > 0) {
    //         msg.sender.transfer(refundShare + partRemaining);
    //     }
    // }    
}