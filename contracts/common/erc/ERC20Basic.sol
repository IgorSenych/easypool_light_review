pragma solidity 0.4.24;


/**
 * @title ERC20Basic
 * @dev ...
 */
contract ERC20Basic {    
    function transfer(address to, uint value) public returns (bool success);
    function balanceOf(address owner) public view returns (uint balance);
}