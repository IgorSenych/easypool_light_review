pragma solidity 0.4.24;

import "../zeppelin/Ownable.sol";
import "../zeppelin/SafeMath.sol";
import "../common/AffiliateBase.sol";
import "../common/FeeServiceBase.sol";


/**
 * @title FeeService
 * @dev ...
 */
contract FeeService is FeeServiceBase, Ownable {     
    using SafeMath for uint;    

    event ServiceFeeChanged(
        uint prevFeePerEther, 
        uint newFeePerEther
    );
    event AffiliateChanged(
        address prevAffiliate, 
        address newAffiliate
    );
    event FeeDistributed(
        address indexed poolCreator,
        address poolAddress,        
        uint totalAmount,
        uint affShare        
    );
    event Withdrawal(
        address destAddress,
        uint amount
    );
    
    AffiliateBase public affiliate;
    uint public feePerEther;        

    /**
     * @dev ...
     */
    function() external {
    }

    /**
     * @dev ...
     */
    function sendFee(address poolCreator) external payable {
        require(
            msg.value > 0 &&
            poolCreator != address(0)
        );        
        
        bool success;
        uint affShare;
        uint sharePerEther;

        if(affiliate != address(0)) {
            (sharePerEther, success) = affiliate.getSharePerEther(poolCreator);
            if(success && sharePerEther > 0) {
                affShare = msg.value.mul(sharePerEther).div(1 ether);
                if(affShare > 0) {
                    affiliate.sendRevenueShare.value(affShare)(poolCreator);
                }            
            }
        }

        emit FeeDistributed(
            poolCreator,
            msg.sender,            
            msg.value,
            affShare
        );
    }

    /**
     * @dev ...
     */
    function withdraw() external onlyOwner {
        emit Withdrawal(msg.sender, address(this).balance);
        owner.transfer(address(this).balance);
    }

    /**
     * @dev ...
     */
    function setFeePerEther(uint newFeePerEther) external onlyOwner {
        emit ServiceFeeChanged(
            feePerEther, 
            newFeePerEther
        );
        feePerEther = newFeePerEther;
    }

    /**
     * @dev ...
     */
    function setAffiliate(address newAffiliate) external onlyOwner {
        emit AffiliateChanged(
            address(affiliate), 
            newAffiliate
        );
        affiliate = AffiliateBase(newAffiliate);
    }

    /**
     * @dev ...
     */
    function getFeePerEther() public view returns(uint) {
        return feePerEther;
    }    
}