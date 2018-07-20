pragma solidity 0.4.24;


/**
 * @title ERC223Receiver
 * @dev ...
 */
contract ERC223Receiver {
    function tokenFallback(address from, uint value, bytes data) public;
}