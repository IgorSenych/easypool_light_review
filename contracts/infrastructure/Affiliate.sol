pragma solidity 0.4.24;

import "../zeppelin/SafeMath.sol";
import "../common/Restricted.sol";
import "../common/AffiliateBase.sol";


/**
 * @title AffiliationManager
 * @dev ...
 */
contract Affiliate is AffiliateBase, Restricted {
    using SafeMath for uint;
                                                              
    event SubscriptionConfirmed(
        address indexed affiliate, 
        address indexed subscriber
    );     
    event AffiliationConfirmed(
        address indexed affiliate, 
        uint indexed modelIndex
    );                  
    event RevenueShareReceived(
        address indexed affiliate, 
        address indexed subscriber, 
        uint affilBalance,
        uint amount
    );
    event ModelRulesChanged(
        uint[] levels,
        uint[] shares,         
        uint index
    );  
    event Withdrawal(
        address indexed affiliate, 
        uint amount
    );          

    /**
     * @dev Affiliate details.
     */
    struct AffiliateData {        
        uint availableBalance;
        uint totalRevenue;
        uint modelIndex;    
        uint curShare;
        uint curLevel;        
        bool exists;
    }

    /**
     * @dev Subscriber details.
     */
    struct SubscriberData {        
        uint generatedRevenue;
        uint transfersCount;        
    }            

    /**
     * @dev Revenue model rule.
     */
    struct ShareRule {
        uint totalRevenue;
        uint sharePerEther;        
    }
    
    address[] public affiliates;
    address[] public subscribers;    

    mapping (address => address) public subToAffiliate;
    mapping (address => address[]) public affiliateToSubs;   
    mapping (address => AffiliateData) public affiliateToData;
    mapping (address => SubscriberData) public subscriberToData;                     
    mapping (uint => ShareRule[]) public models;    
    uint public curModelIndex = 0;   
    
    /**
    @dev Constructor function.
    */
    constructor() public {
        models[curModelIndex].push(ShareRule(uintMaxValue(), 0));
    }

    /**
    * @dev Allows the new affiliate to confirm its address (become an affiliate)
    * and allows the current affiliate to change its revenue share model.    
    */
    function confirmAffiliation() external {        
        AffiliateData storage aData = affiliateToData[msg.sender];   

        if(aData.exists) {
            require(aData.modelIndex != curModelIndex);
            aData.modelIndex = curModelIndex;  
            updateLevelAndShare(aData);
        } else {                     
            affiliates.push(msg.sender);
            aData.modelIndex = curModelIndex;   
            aData.curShare = models[curModelIndex][0].sharePerEther;
            aData.curLevel = models[curModelIndex][0].totalRevenue;              
            aData.exists = true;        
        }        
        
        emit AffiliationConfirmed(
            msg.sender, 
            aData.modelIndex
        );
    }

    /**
    * @dev Links subscriber address with an affiliate address.    
    */
    function linkSubscriber(address affiliate) external {
        require(
            affiliate != address(0) &&
            subToAffiliate[msg.sender] == address(0) &&
            affiliateToData[affiliate].exists
        );            
                                
        subscribers.push(msg.sender);
        subToAffiliate[msg.sender] = affiliate;                
        affiliateToSubs[affiliate].push(msg.sender);         

        emit SubscriptionConfirmed(affiliate, msg.sender);
    }

    /**
    * @dev Allows to withdraw funds from the contract.
    */
    function withdraw() external {        
        uint amount = affiliateToData[msg.sender].availableBalance; 
        require(amount != 0);

        affiliateToData[msg.sender].availableBalance = 0;
        msg.sender.transfer(amount);

        emit Withdrawal(msg.sender, amount);
    } 
    
    /**
     * @dev ...
     */
    function setModelRules(uint[] levels, uint[] shares) external onlyOwner {    
        require(
            levels.length > 0 && 
            levels.length == shares.length
        );                

        curModelIndex++;
        ShareRule[] storage rules = models[curModelIndex];                

        uint last = levels.length - 1;
        for (uint i = 0; i < last; i++) {  
            require(levels[i] < levels[i + 1]);                                              
            rules.push(ShareRule(levels[i], shares[i]));            
        }           
        rules.push(ShareRule(uintMaxValue(), shares[last]));        
            
        emit ModelRulesChanged(
            levels, 
            shares,             
            curModelIndex
        );
    }

    /**
    * @dev Allows the current controller to transfer affiliate's revenue share.
    */
    function sendRevenueShare(address subscriber) external payable onlyOperator {
        require(
            msg.value > 0 &&
            subscriber != address(0) &&
            subToAffiliate[subscriber] != address(0)
        );
        
        // This is not possible.
        // require(aData.exists);
        // require(subscriber.exists);
        // subscriptions[subscriber] == affiliate Solves this!
        
        AffiliateData storage aData = affiliateToData[subToAffiliate[subscriber]];                
        aData.availableBalance = aData.availableBalance.add(msg.value);  
        aData.totalRevenue = aData.totalRevenue.add(msg.value);                        
        if(aData.totalRevenue > aData.curLevel) {
            updateLevelAndShare(aData);
        }
        
        SubscriberData storage sData = subscriberToData[subscriber];        
        sData.generatedRevenue = sData.generatedRevenue.add(msg.value);                
        sData.transfersCount++;                 

        emit RevenueShareReceived(
            subToAffiliate[subscriber], 
            subscriber,
            aData.availableBalance,
            msg.value            
        );
    }

    /**
     * @dev ...
     */
    function updateLevelAndShare(AffiliateData storage aData) private {
        ShareRule[] storage rules = models[aData.modelIndex];        
        for (uint i = 0; i < rules.length; i++) {
            if(aData.totalRevenue <= rules[i].totalRevenue) {
                aData.curShare = rules[i].sharePerEther;
                aData.curLevel = rules[i].totalRevenue;                
                return;
            }
        }        
    }

    /**
     * @dev ...
     */
    function getSharePerEther(address subscriber) public view returns(uint sharePerEther, bool success) {
        if(subToAffiliate[subscriber] != address(0)) {
            AffiliateData storage aData = affiliateToData[subToAffiliate[subscriber]];        
            if(aData.exists) {
                sharePerEther = aData.curShare;
                success = true;
            }            
        }                        
    }
    
    /**
     * @dev ...
     */
    function getModelRules(uint modelIndex) public view returns(uint[] levels, uint[] shares) {            
        ShareRule[] storage rules = models[modelIndex];  
        levels = new uint[](rules.length);
        shares = new uint[](rules.length);        

        for (uint i = 0; i < rules.length; i++) {
            shares[i] = rules[i].sharePerEther;
            levels[i] = rules[i].totalRevenue;            
        }            
    }        

    /**
     * @dev Returns all affiliates.
     */
    function getAllAffiliates() external view returns(address[]) {
        return affiliates;
    }

    /**
     * @dev Returns all subscribers.
     */
    function getAllSubscribers() external view returns(address[]) {
        return subscribers;
    }

    /**
     * @dev Returns subscribers for specified affiliate.     
     */
    function getAffiliateSubscribers(address affiliate) external view returns(address[]) {
        return affiliateToSubs[affiliate];
    }

    /**
     * @dev ...
     */
    function uintMaxValue() private pure returns(uint) {
        // TODO: Nethereum return -1 for max value.
        // return 2**256 - 1;
        return 1e9 ether;
    }
}