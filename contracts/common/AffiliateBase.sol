pragma solidity 0.4.24;


/**
 * @title AffiliateBase
 * @dev ...
 */
contract AffiliateBase {    
    function getSharePerEther(address subscriber) public view returns(uint sharePerEther, bool success);
    function sendRevenueShare(address subscriber) external payable;
}