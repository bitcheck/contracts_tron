/**
 *  $$$$$$\  $$\                 $$\                           
 * $$  __$$\ $$ |                $$ |                          
 * $$ /  \__|$$$$$$$\   $$$$$$\  $$ |  $$\  $$$$$$\   $$$$$$\  
 * \$$$$$$\  $$  __$$\  \____$$\ $$ | $$  |$$  __$$\ $$  __$$\ 
 *  \____$$\ $$ |  $$ | $$$$$$$ |$$$$$$  / $$$$$$$$ |$$ |  \__|
 * $$\   $$ |$$ |  $$ |$$  __$$ |$$  _$$<  $$   ____|$$ |      
 * \$$$$$$  |$$ |  $$ |\$$$$$$$ |$$ | \$$\ \$$$$$$$\ $$ |      
 *  \______/ \__|  \__| \_______|\__|  \__| \_______|\__|
 * $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
 * ____________________________________________________________
*/

pragma solidity >=0.4.23 <0.6.0;

import "./ERC20.sol";
import "./ERC20Detailed.sol";

contract SKRToken is ERC20, ERC20Detailed {
    address public authorizedContract;
    address public operator;
    
    constructor (address _authorizedContract) public ERC20Detailed("ShakerDAO", "SKR", 6) {
        operator = msg.sender;
        authorizedContract = _authorizedContract;
        // zero pre-mine
    }
    
    modifier onlyOperator {
        require(msg.sender == operator, "Only operator can call this function.");
        _;
    }

    modifier onlyAuthorizedContract {
        require(msg.sender == authorizedContract, "Only authorized contract can call this function.");
        _;
    }

    function mint(address account, uint256 amount) public onlyAuthorizedContract {
        _mint(account, amount);
    }
    
    function burn(address account, uint256 amount) public onlyAuthorizedContract {
        _burn(account, amount);
    }
    
    function updateOperator(address _newOperator) external onlyOperator {
        require(_newOperator != address(0));
        operator = _newOperator;
    }
    
    function updateAuthorizedContract(address _authorizedContract) external onlyOperator {
        require(_authorizedContract != address(0));
        authorizedContract = _authorizedContract;
    }

}