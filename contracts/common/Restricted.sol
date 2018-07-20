pragma solidity 0.4.24;

import "../zeppelin/Ownable.sol";


/**
 * @title Restricted
 * @dev The Restricted contract has an array of operator addresses 
 * and provides basic "restricted access" functionality. 
 */
contract Restricted is Ownable {

    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);    

    address[] public operators;
    mapping(address => bool) public permissions;    

    /**
     * @dev Throws if called by any account other than the operator.
     */
    modifier onlyOperator() {
        require(permissions[msg.sender]);
        _;
    }

    /**
    * @dev Allows the current owner to add new operator address.    
    */
    function addOperator(address operator) external onlyOwner {        
        require(
            operator != address(0) &&
            !permissions[operator]
        );

        operators.push(operator);
        permissions[operator] = true;
        emit OperatorAdded(operator);
    }

    /**
    * @dev Allows the current owner to remove specified operator. 
    */
    function removeOperator(address operator) external onlyOwner {        
        require(
            operator != address(0) && 
            permissions[operator]
        );  

        uint deleteIndex;
        uint lastIndex = operators.length - 1;
        for (uint i = 0; i <= lastIndex; i++) {
            if(operators[i] == operator) {
                deleteIndex = i;
                break;
            }
        }
        
        if (deleteIndex < lastIndex) {
            operators[deleteIndex] = operators[lastIndex];             
        }

        delete operators[lastIndex];
        operators.length--;              

        permissions[operator] = false;        
        emit OperatorRemoved(operator);
    }

    /**
     * @dev Returns all operators.
     */
    function getOperators() public view returns(address[]) {
        return operators;
    }
}

