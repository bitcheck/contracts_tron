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

import "./Mocks/BTCHToken.sol";
import "./ReentrancyGuard.sol";
import "./Mocks/SafeMath.sol";

contract DividendPool is ReentrancyGuard {
    using SafeMath for uint256;
    uint256 public totalBalance = 0;
    address public tokenAddress;    // BTCH
    address public dividentAddress; // USDT Token
    address public feeAddress; // must be same as commonWithdrawAddress in ShakerV2.sol
    address public operator;
    
    // Share dividents of fee
    uint256 public currentStartTimestamp = 0;
    uint256 public totalDividents = 0;
    uint256 public sentDividents = 0;
    uint256 public getDividentsTimeout = 172800;// Have 2 days to getting current dividents
    
    event Dividend(address to, uint256 amount, uint256 timestamp);
    
    mapping(address => uint256) private lastGettingDividentsTime;
    mapping(address => uint256) public balances;

    BTCHToken public token;
    ERC20 public dividentToken;

    modifier onlyOperator {
        require(msg.sender == operator, "Only operator can call this function.");
        _;
    }

    constructor(
      address _tokenAddress, 
      address _dividentAddress, 
      address _feeAddress
    ) public {
        tokenAddress = _tokenAddress;
        token = BTCHToken(tokenAddress);
        dividentAddress = _dividentAddress;
        dividentToken = ERC20(dividentAddress);
        operator = msg.sender;
        feeAddress = _feeAddress;
    }
    
    function depositBTCH(uint256 amount) external nonReentrant {
        require(amount > 0);
        require(!(block.timestamp <= currentStartTimestamp + getDividentsTimeout) || !(block.timestamp >= currentStartTimestamp), "You can not deposit during taking divident time");
        require(amount <= token.balanceOf(msg.sender), "Your balance is not enough");
        require(token.allowance(msg.sender, address(this)) >= amount, "Your allowance is not enough");
        token.transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] = balances[msg.sender].add(amount);
        totalBalance = totalBalance.add(amount);
    }
    
    function withdrawBTCH(uint256 amount) external nonReentrant {
        require(amount > 0);
        require(!(block.timestamp <= currentStartTimestamp + getDividentsTimeout) || !(block.timestamp >= currentStartTimestamp), "You can not withdraw during taking divident time");
        require(amount <= balances[msg.sender], "Your deposit balance is not enough");
        token.transfer(msg.sender, amount);
        balances[msg.sender] = balances[msg.sender].sub(amount);
        totalBalance = totalBalance.sub(amount);
    }

    function updateTokenAddress(address _addr) external onlyOperator nonReentrant {
      require(_addr != address(0));
      tokenAddress = _addr;
      token = BTCHToken(tokenAddress);
    }

    function updateOperator(address _addr) external onlyOperator nonReentrant {
      require(_addr != address(0));
      operator = _addr;
    }

    function getBalance() external view returns(uint256) {
      return balances[msg.sender];
    }
    
    function getDividentsAmount() public view returns(uint256, uint256) {
      // Caculate normal dividents
      require(totalBalance > 0);
      return (totalDividents.mul(balances[msg.sender]).div(totalBalance), lastGettingDividentsTime[msg.sender]);
    }
    
    function setDividentAddress(address _address) external onlyOperator {
      dividentAddress = _address;
      dividentToken = ERC20(dividentAddress);
    }

    function setFeeAddress(address _address) external onlyOperator {
        require(_address != address(0));
        feeAddress = _address;
    }

    function sendDividents() external nonReentrant {
      // Only shaker contract can call this function
      require(block.timestamp <= currentStartTimestamp + getDividentsTimeout && block.timestamp >= currentStartTimestamp, "Getting dividents not start or it's already end");
      require(lastGettingDividentsTime[msg.sender] < currentStartTimestamp, "You have got dividents already");
      (uint256 normalDividents,) = getDividentsAmount();
      
      // Send Dividents
      // The fee account must approve the this contract enough allowance of USDT as dividend
      require(dividentToken.allowance(feeAddress, address(this)) >= normalDividents, "Allowance not enough");
      dividentToken.transferFrom(feeAddress, msg.sender, normalDividents);
      sentDividents = sentDividents.add(normalDividents);
      lastGettingDividentsTime[msg.sender] = block.timestamp;
      emit Dividend(msg.sender, normalDividents, block.timestamp);
    }

    /** Start Dividents by operator */
    function startDividents(uint256 from, uint256 amount) external onlyOperator nonReentrant{
      require(from > block.timestamp);
      require(amount > 0);
      currentStartTimestamp = from;
      totalDividents = amount;
      sentDividents = 0;
    }

    function setGettingDividentsTimeout(uint256 _seconds) external onlyOperator {
      getDividentsTimeout = _seconds;
    }

    function getLastTakingDividentsTime() external view returns(uint256) {
      return lastGettingDividentsTime[msg.sender];
    }
}