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

import "./Mocks/ERC20.sol";
import "./Mocks/SafeMath.sol";

contract Vault {
    using SafeMath for uint256;
    ERC20 private erc20;
    address public erc20Address;
    uint256 public totalAmount = 0; // Total amount of deposit
    uint256 public totalBalance = 0; // Total balance of deposit after Withdrawal

    struct Commitment {                 // Deposit Commitment
        bool            status;             // If there is no this commitment or balance is zeor, false
        uint256         amount;             // Deposit balance
        address payable sender;         // Who make this deposit
        uint256         effectiveTime;      // Forward cheque time
        uint256         timestamp;          // Deposit timestamp
        bool            canEndorse;
        bool            lockable;           // If can be locked/refund
        uint256         params1;
        uint256         params2;
        uint256         params3;
        address         params4;
    }
    // Mapping of commitments, must be private. The key is hashKey = hash(commitment,recipient)
    // The contract will hide the recipient and commitment while make deposit.
    mapping(bytes32 => Commitment) private commitments; 
    address public operator;
    address public shakerContractAddress;

    event Deposit(address sender, bytes32 hashkey, uint256 amount, uint256 timestamp);
    event Withdrawal(string commitment, uint256 fee, uint256 amount, uint256 timestamp);

    function sendDepositEvent(address _sender, bytes32 _hashkey, uint256 _amount, uint256 _timestamp) external onlyShaker {
      emit Deposit(_sender, _hashkey, _amount, _timestamp);
    }

    function sendWithdrawEvent(string calldata _commitment, uint256 _fee, uint256 _amount, uint256 _timestamp) external onlyShaker {
      emit Withdrawal(_commitment, _fee, _amount, _timestamp);
    }

    modifier onlyOperator {
        require(msg.sender == operator, "Only operator can call this function.");
        _;
    }

    modifier onlyShaker {
        require(msg.sender == shakerContractAddress, "Only bitcheck contract can call this function.");
        _;
    }

    constructor(address _erc20Address) public {
        operator = msg.sender;
        erc20Address = _erc20Address;
        erc20 = ERC20(erc20Address);
    }

    function setStatus(bytes32 _hashkey, bool _status) external onlyShaker {
        commitments[_hashkey].status = _status;
    }
    
    function setAmount(bytes32 _hashkey, uint256 _amount) external onlyShaker {
        commitments[_hashkey].amount = _amount;
    }
    
    function setSender(bytes32 _hashkey, address payable _sender) external onlyShaker {
        commitments[_hashkey].sender = _sender;
    }
    
    function setEffectiveTime(bytes32 _hashkey, uint256 _effectiveTime) external onlyShaker {
        commitments[_hashkey].effectiveTime = _effectiveTime;
    }
    
    function setTimestamp(bytes32 _hashkey, uint256 _timestamp) external onlyShaker {
        commitments[_hashkey].timestamp = _timestamp;
    }
    
    function setCanEndorse(bytes32 _hashkey, bool _canEndorse) external onlyShaker {
        commitments[_hashkey].canEndorse = _canEndorse;
    }
    
    function setLockable(bytes32 _hashkey, bool _lockable) external onlyShaker {
        commitments[_hashkey].lockable = _lockable;
    }

    function setParams1(bytes32 _hashkey, uint256 _params1) external onlyShaker {
        commitments[_hashkey].params1 = _params1;
    }

    function setParams2(bytes32 _hashkey, uint256 _params2) external onlyShaker {
        commitments[_hashkey].params2 = _params2;
    }

    function setParams3(bytes32 _hashkey, uint256 _params3) external onlyShaker {
        commitments[_hashkey].params3 = _params3;
    }

    function setParams4(bytes32 _hashkey, address _params4) external onlyShaker {
        commitments[_hashkey].params4 = _params4;
    }
    
    
    function getStatus(bytes32 _hashkey) external view onlyShaker returns(bool) {
        return commitments[_hashkey].status;
    }
    
    function getAmount(bytes32 _hashkey) external view onlyShaker returns(uint256) {
        return commitments[_hashkey].amount;
    }
    
    function getSender(bytes32 _hashkey) external view onlyShaker returns(address payable) {
        return commitments[_hashkey].sender;
    }
    
    function getEffectiveTime(bytes32 _hashkey) external view onlyShaker returns(uint256) {
        return commitments[_hashkey].effectiveTime;
    }
    
    function getTimestamp(bytes32 _hashkey) external view onlyShaker returns(uint256) {
        return commitments[_hashkey].timestamp;
    }
    
    function getCanEndorse(bytes32 _hashkey) external view onlyShaker returns(bool) {
        return commitments[_hashkey].canEndorse;
    }
    
    function getLockable(bytes32 _hashkey) external view onlyShaker returns(bool) {
        return commitments[_hashkey].lockable;
    }    

    function getParams1(bytes32 _hashkey) external view onlyShaker returns(uint256) {
        return commitments[_hashkey].params1;
    }

    function getParams2(bytes32 _hashkey) external view onlyShaker returns(uint256) {
        return commitments[_hashkey].params2;
    }

    function getParams3(bytes32 _hashkey) external view onlyShaker returns(uint256) {
        return commitments[_hashkey].params3;
    }

    function getParams4(bytes32 _hashkey) external view onlyShaker returns(address) {
        return commitments[_hashkey].params4;
    }
    
    function updateOperator(address _operator) external onlyOperator {
        operator = _operator;
    }

    function updateShakerAddress(address _shaker, uint256 _allowance) external onlyOperator returns(bool) {
        shakerContractAddress = _shaker;
        //Approve shaker contract
        erc20.approve(shakerContractAddress, _allowance);
        return true;
    }

    function getShakerAllowance() external view returns(uint256) {
      return erc20.allowance(address(this), shakerContractAddress);
    }

    function addTotalAmount(uint256 _amount) external onlyShaker {
        totalAmount = totalAmount.add(_amount);
    }

    function addTotalBalance(uint256 _amount) external onlyShaker {
        totalBalance = totalBalance.add(_amount);
    }

    function subTotalBalance(uint256 _amount) external onlyShaker {
        totalBalance = totalBalance.sub(_amount);
    }
}