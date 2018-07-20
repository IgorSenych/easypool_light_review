pragma solidity 0.4.24;


/**
 * @title FeeServiceBase
 * @dev ...
 */
contract FeeServiceBase {
    function getFeePerEther() public view returns(uint);    
    function sendFee(address payer) external payable;
}