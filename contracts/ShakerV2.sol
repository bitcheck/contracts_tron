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

import "./ReentrancyGuard.sol";
import "./SafeMath.sol";
import "./StringUtils.sol";

contract ShakerV2 is ReentrancyGuard, StringUtils {
    using SafeMath for uint256;
    uint256 public totalAmount = 0; // Total amount of deposit
    uint256 public totalBalance = 0; // Total balance of deposit after Withdrawal

    address public operator;            // Super operator account to control the contract
    address public councilAddress;      // Council address of DAO

    struct Commitment {                 // Deposit Commitment
        bool        status;             // If there is no this commitment or balance is zeor, false
        uint256     amount;             // Deposit balance
        address payable sender;         // Who make this deposit
        uint256     effectiveTime;      // Forward cheque time
    }
    // Mapping of commitments, must be private. The key is hashKey = hash(commitment,recipient)
    // The contract will hide the recipient and commitment while make deposit.
    mapping(bytes32 => Commitment) private commitments; 
    
    // Relayer is service to do the deposit and Withdrawal on server, this address is for recieving fee
    mapping(address => address) private relayerWithdrawAddress;
    
    // If the msg.sender(relayer) has not registered Withdrawal address, the fee will send to this address
    address public commonWithdrawAddress; 
    
    // If withdrawal is not throught relayer, use this common fee. Be care of decimal of token
    uint256 public commonFee = 0; 
    
    // If withdrawal is not throught relayer, use this rate. Total fee is: commoneFee + amount * commonFeeRate. 
    // If the desired rate is 4%, commonFeeRate should set to 400
    uint256 public commonFeeRate = 0; 
    
    struct LockReason {
        string  description;
        uint8   status; // 1- locked, 2- unlocked, 0- never happend
        uint256 datetime;
        bytes32 hashKey;
        uint256 refund;
        address locker;
        bool    recipientAgree;
        bool    senderAgree;
        address newRecipient;
    }
    // locakReason key is hashKey = hash(commitment, recipient)
    mapping(bytes32 => LockReason) private lockReason;

    modifier onlyOperator {
        require(msg.sender == operator, "Only operator can call this function.");
        _;
    }

    modifier onlyRelayer {
        require(relayerWithdrawAddress[msg.sender] != address(0x0), "Only relayer can call this function.");
        _;
    }
    
    modifier onlyCouncil {
        require(msg.sender == councilAddress, "Only council account can call this function.");
        _;
    }
    
    event Deposit(address sender, bytes32 hashkey, uint256 amount, uint256 timestamp);
    event Withdrawal(string commitment, uint256 fee, uint256 amount, uint256 timestamp);

    constructor(
        address _operator,
        address _commonWithdrawAddress
    ) public {
        operator = _operator;
        commonWithdrawAddress = _commonWithdrawAddress;
    }

    function depositERC20Batch(
        bytes32[] calldata _hashKey,
        uint256[] calldata _amounts, 
        uint256[] calldata _effectiveTime
    ) external payable nonReentrant {
        for(uint256 i = 0; i < _amounts.length; i++) {
            _deposit(_hashKey[i], _amounts[i], _effectiveTime[i]);
        }
    }
  
    function _deposit(
        bytes32 _hashKey,
        uint256 _amount, 
        uint256 _effectiveTime
    ) internal {
        require(!commitments[_hashKey].status, "The commitment has been submitted or used out.");
        require(_amount > 0);
        
        _processDeposit(_amount);
        
        commitments[_hashKey].status = true;
        commitments[_hashKey].amount = _amount;
        commitments[_hashKey].sender = msg.sender;
        commitments[_hashKey].effectiveTime = _effectiveTime < block.timestamp ? block.timestamp : _effectiveTime;

        totalAmount = totalAmount.add(_amount);
        totalBalance = totalBalance.add(_amount);

        emit Deposit(msg.sender, _hashKey, _amount, block.timestamp);
    }

    function _processDeposit(uint256 _amount) internal;

    function withdrawERC20Batch(
        bytes32[] calldata _commitments,
        uint256[] calldata _amounts,
        uint256[] calldata _fees,
        address[] calldata _relayers
    ) external payable nonReentrant {
        for(uint256 i = 0; i < _commitments.length; i++) _withdraw(bytes32ToString(_commitments[i]), _amounts[i], _fees[i], _relayers[i]);
    }
    
    function _withdraw(
        string memory _commitment,
        uint256 _amount,                // Withdrawal amount
        uint256 _fee,                    // Fee caculated by relayer
        address _relayer                // Relayer address
    ) internal {
        bytes32 _hashkey = getHashkey(_commitment);
        require(commitments[_hashkey].amount > 0, 'The commitment of this recipient is not exist or used out');
        require(lockReason[_hashkey].status != 1, 'This deposit was locked');
        uint256 refundAmount = _amount < commitments[_hashkey].amount ? _amount : commitments[_hashkey].amount; //Take all if _refund == 0
        require(refundAmount > 0, "Refund amount can not be zero");
        require(block.timestamp >= commitments[_hashkey].effectiveTime, "The deposit is locked until the effectiveTime");
        require(refundAmount >= _fee, "Refund amount should be more than fee");

        address relayer = relayerWithdrawAddress[_relayer] == address(0x0) ? commonWithdrawAddress : relayerWithdrawAddress[_relayer];
        uint256 _fee1 = getFee(refundAmount);
        require(_fee1 <= refundAmount, "The fee can not be more than refund amount");
        uint256 _fee2 = relayerWithdrawAddress[_relayer] == address(0x0) ? _fee1 : _fee; // If not through relay, use commonFee
        _processWithdraw(msg.sender, relayer, _fee2, refundAmount);
    
        commitments[_hashkey].amount = (commitments[_hashkey].amount).sub(refundAmount);
        commitments[_hashkey].status = commitments[_hashkey].amount <= 0 ? false : true;
        totalAmount = totalAmount.sub(refundAmount);

        emit Withdrawal(_commitment, _fee, refundAmount, block.timestamp);
    }

    function _processWithdraw(address payable _recipient, address _relayer, uint256 _fee, uint256 _refund) internal;

    function getHashkey(string memory _commitment) internal view returns(bytes32) {
        string memory commitAndTo = concat(_commitment, addressToString(msg.sender));
        return keccak256(abi.encodePacked(commitAndTo));
    }
    
    function endorseERC20Batch(
        uint256[] calldata _amounts,
        bytes32[] calldata _oldCommitments,
        bytes32[] calldata _newHashKeys,
        uint256[] calldata _effectiveTimes
    ) external payable nonReentrant {
        for(uint256 i = 0; i < _amounts.length; i++) _endorse(_amounts[i], bytes32ToString(_oldCommitments[i]), _newHashKeys[i], _effectiveTimes[i]);
    }
    
    function _endorse(
        uint256 _amount, 
        string memory _oldCommitment, 
        bytes32 _newHashKey, 
        uint256 _effectiveTime
    ) internal {
        bytes32 _oldHashKey = getHashkey(_oldCommitment);
        require(lockReason[_oldHashKey].status != 1, 'This deposit was locked');
        require(commitments[_oldHashKey].status, "Old commitment can not find");
        require(!commitments[_newHashKey].status, "The new commitment has been submitted or used out");
        require(commitments[_oldHashKey].amount > 0, "No balance amount of this proof");
        uint256 refundAmount = _amount < commitments[_oldHashKey].amount ? _amount : commitments[_oldHashKey].amount; //Take all if _refund == 0
        require(refundAmount > 0, "Refund amount can not be zero");

        if(_effectiveTime > 0 && block.timestamp >= commitments[_oldHashKey].effectiveTime) commitments[_oldHashKey].effectiveTime = _effectiveTime; // Effective
        else commitments[_newHashKey].effectiveTime = commitments[_oldHashKey].effectiveTime; // Not effective
        
        commitments[_newHashKey].status = true;
        commitments[_newHashKey].amount = refundAmount;
        commitments[_newHashKey].sender = msg.sender;

        commitments[_oldHashKey].amount = (commitments[_oldHashKey].amount).sub(refundAmount);
        commitments[_oldHashKey].status = commitments[_oldHashKey].amount <= 0 ? false : true;

        emit Withdrawal(_oldCommitment,  0, refundAmount, block.timestamp);
        emit Deposit(msg.sender, _newHashKey, refundAmount, block.timestamp);
    }
    
    /** @dev whether a note is already spent */
    function isSpent(bytes32 _hashkey) public view returns(bool) {
        return commitments[_hashkey].amount == 0 ? true : false;
    }

    /** @dev whether an array of notes is already spent */
    function isSpentArray(bytes32[] calldata _hashkeys) external view returns(bool[] memory spent) {
        spent = new bool[](_hashkeys.length);
        for(uint i = 0; i < _hashkeys.length; i++) spent[i] = isSpent(_hashkeys[i]);
    }

    /** @dev operator can change his address */
    function updateOperator(address _newOperator) external nonReentrant onlyOperator {
        operator = _newOperator;
    }

    /** @dev update authority relayer */
    function updateRelayer(address _relayer, address _withdrawAddress) external nonReentrant onlyOperator {
        relayerWithdrawAddress[_relayer] = _withdrawAddress;
    }
    
    /** @dev get relayer Withdrawal address */
    function getRelayerWithdrawAddress() view external onlyRelayer returns(address) {
        return relayerWithdrawAddress[msg.sender];
    }
    
    /** @dev update commonWithdrawAddress */
    function updateCommonWithdrawAddress(address _commonWithdrawAddress) external nonReentrant onlyOperator {
        commonWithdrawAddress = _commonWithdrawAddress;
    }
    
    /** @dev set council address */
    function setCouncial(address _councilAddress) external nonReentrant onlyOperator {
        councilAddress = _councilAddress;
    }
    
    /** @dev lock commitment, this operation can be only called by note holder */
    function lockERC20Batch (
        bytes32             _hashkey,
        string   calldata   _description
    ) external payable nonReentrant {
        _lock(_hashkey, _description);
    }
    
    function _lock(
        bytes32 _hashkey,
        string memory _description
    ) internal {
        require(msg.sender == commitments[_hashkey].sender, 'Locker must be recipient, sender or council');
        
        lockReason[_hashkey] = LockReason(
            _description, 
            1,
            block.timestamp,
            _hashkey,
            commitments[_hashkey].amount,
            msg.sender,
            false,
            false,
            address(0x0)
        );
    }
    
    function getLockReason(bytes32 _hashkey) public view returns(
        string memory description, 
        uint8 status, 
        uint256 datetime, 
        bytes32 hashKey, 
        uint256 refund, 
        address locker, 
        bool recipientAgree, 
        bool senderAgree, 
        address newRecipient
    ) {
        LockReason memory data = lockReason[_hashkey];
        return (data.description, data.status, data.datetime, data.hashKey, data.refund, data.locker, data.recipientAgree, data.senderAgree, data.newRecipient);
        
    }
    
    /** @dev unlock commitment by council */
    // _recipient is only effective while it is depositer's address, that mean the the depositer will refund. Otherwise, just unlock the commitment, the original recipient will withdraw as usual.
    function unlockByCouncil(bytes32 _hashkey, address payable _recipient) external nonReentrant onlyCouncil {
        require(_recipient != address(0x0));
        if(lockReason[_hashkey].status == 1) {
            lockReason[_hashkey].status = 2;
            // If the council decided to return back money to the sender
            if(_recipient == commitments[_hashkey].sender) {
                _processWithdraw(_recipient, address(0x0), 0, commitments[_hashkey].amount);
                commitments[_hashkey].amount = 0;
                commitments[_hashkey].status = false;
            }
        }
    }
    
    /**
     * Both of parties should agree with the new recipient address and unlock the commitment
     * This is 1st step if dispute happend
     * _recipient is only effective while it is depositer's address, that mean the the depositer will refund. Otherwise, just unlock the commitment, the original recipient will withdraw as usual.
     */
    function unlockByParties(bytes32 _hashkey, string calldata _commitment, address payable _recipient) external nonReentrant returns(bool) {
        require(_recipient != address(0x0));
        LockReason memory lock = lockReason[_hashkey];
        bytes32 _recipientHashKey = getHashkey(_commitment);
        require(msg.sender == commitments[_hashkey].sender || _hashkey == _recipientHashKey, 'Must be called by recipient or original sender');
        bool unlock = false;
        if(lock.status == 1) {
            if(lock.recipientAgree && msg.sender == commitments[_hashkey].sender && !lock.senderAgree && _recipient == lock.newRecipient) {
                unlock = true;
                lock.senderAgree = true;
            } else if(!lock.recipientAgree && _hashkey == _recipientHashKey && lock.senderAgree && _recipient == lock.newRecipient) {
                unlock = true;
                lock.recipientAgree = true;
            } else if(_hashkey == _recipientHashKey && !lock.recipientAgree) {
                lock.recipientAgree = true;
                lock.newRecipient = _recipient;
            } else if(msg.sender == commitments[_hashkey].sender && !lock.senderAgree) {
                lock.senderAgree = true;
                lock.newRecipient = _recipient;
            } else if(lock.recipientAgree && lock.senderAgree) {
                unlock = true;
            }
            if(unlock) {
                lock.status = 2;
                // If the council decided to return back money to the sender
                if(_recipient == commitments[_hashkey].sender) {
                    _processWithdraw(_recipient, address(0x0), 0, commitments[_hashkey].amount);
                    commitments[_hashkey].amount = 0;
                    commitments[_hashkey].status = false;
                }
                return true;
            } else {
                return false;
            }
        } else {
          return false;
        }
    }
    
    /**
     * Cancel effectiveTime and change cheque to at sight
     */
    function changeToAtSight(bytes32 _hashkey) external nonReentrant returns(bool) {
        require(msg.sender == commitments[_hashkey].sender, 'Only sender can change this cheque to at sight');
        if(commitments[_hashkey].effectiveTime > block.timestamp) commitments[_hashkey].effectiveTime = block.timestamp;
        return true;
    }
    
    function getEffectiveTime(bytes32 _hashkey) external view returns(uint256) {
        return commitments[_hashkey].effectiveTime;
    }

    /** @dev set common fee and fee rate */
    function updateCommonFee(uint256 _fee, uint256 _rate) external nonReentrant onlyOperator {
        commonFee = _fee;
        commonFeeRate = _rate;
    }
    
    /** @dev caculate the fee according to amount */
    function getFee(uint256 _amount) internal view returns(uint256) {
        return _amount * commonFeeRate / 10000 + commonFee;
    }

}
