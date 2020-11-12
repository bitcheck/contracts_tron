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
import "./StringUtils.sol";
import "./ShakerTokenManager.sol";
import "./Vault.sol";

contract ShakerV2 is ReentrancyGuard, StringUtils {
    using SafeMath for uint256;
    uint256 public totalAmount = 0; // Total amount of deposit
    uint256 public totalBalance = 0; // Total balance of deposit after Withdrawal

    address public operator;            // Super operator account to control the contract
    address public councilAddress;      // Council address of DAO
    uint256 public councilJudgementFee = 0; // Council charge for judgement
    uint256 public councilJudgementFeeRate = 1700; // If the desired rate is 17%, commonFeeRate should set to 1700
    uint256 public minReplyHours = 3 * 24;

    ShakerTokenManager public tokenManager;
    address public vaultAddress;
    Vault public vault;
    
    mapping(address => address) private relayerWithdrawAddress;
    
    // If the msg.sender(relayer) has not registered Withdrawal address, the fee will send to this address
    address public commonWithdrawAddress; 
    
    // If withdrawal is not throught relayer, use this common fee. Be care of decimal of token
    // uint256 public commonFee = 0; 
    
    // If withdrawal is not throught relayer, use this rate. Total fee is: commoneFee + amount * commonFeeRate. 
    // If the desired rate is 4%, commonFeeRate should set to 400
    // uint256 public commonFeeRate = 25; // 0.25% 
    
    struct LockReason {
        string  description;
        uint8   status;         // 0- never happend, 1- locked, 2- confirm by recipient, 3- unlocked by council, 4- cancel refund by sender, 5- refund by sender himself
        uint256 datetime;       // Lock date
        uint256 replyDeadline;  // If the recipent don't reply(confirm or don't confirm) during this time, the sender can refund 
        uint256 refund;
        address payable locker;
        bool    recipientAgree;
        bool    senderAgree;
        bool    toCouncil;
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
        address _commonWithdrawAddress,
        address _vaultAddress
    ) public {
        operator = _operator;
        councilAddress = _operator;
        commonWithdrawAddress = _commonWithdrawAddress;
        vaultAddress = _vaultAddress;
        vault = Vault(vaultAddress);
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
        require(!vault.getStatus(_hashKey), "The commitment has been submitted or used out.");
        require(_amount > 0);
        
        _processDeposit(_amount, vaultAddress);
        
        vault.setStatus(_hashKey, true);
        vault.setAmount(_hashKey, _amount);
        vault.setSender(_hashKey, msg.sender);
        vault.setEffectiveTime(_hashKey, _effectiveTime < block.timestamp ? block.timestamp : _effectiveTime);
        vault.setTimestamp(_hashKey, block.timestamp);
        vault.setCanEndorse(_hashKey, false);
        vault.setLockable(_hashKey, true);
        
        totalAmount = totalAmount.add(_amount);
        totalBalance = totalBalance.add(_amount);

        emit Deposit(msg.sender, _hashKey, _amount, block.timestamp);
    }

    function _processDeposit(uint256 _amount, address _to) internal;

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
        require(vault.getAmount(_hashkey) > 0, 'The commitment of this recipient is not exist or used out');
        require(lockReason[_hashkey].status != 1, 'This deposit was locked');
        uint256 refundAmount = _amount < vault.getAmount(_hashkey) ? _amount : vault.getAmount(_hashkey); //Take all if _refund == 0
        require(refundAmount > 0, "Refund amount can not be zero");
        require(block.timestamp >= vault.getEffectiveTime(_hashkey), "The deposit is locked until the effectiveTime");
        require(refundAmount >= _fee, "Refund amount should be more than fee");

        address relayer = relayerWithdrawAddress[_relayer] == address(0x0) ? commonWithdrawAddress : relayerWithdrawAddress[_relayer];
        uint256 _fee1 = tokenManager.getFee(refundAmount);
        require(_fee1 <= refundAmount, "The fee can not be more than refund amount");
        uint256 _fee2 = relayerWithdrawAddress[_relayer] == address(0x0) ? _fee1 : _fee; // If not through relay, use commonFee
        _processWithdraw(msg.sender, relayer, _fee2, refundAmount);
    
        vault.setAmount(_hashkey, vault.getAmount(_hashkey).sub(refundAmount));
        vault.setStatus(_hashkey, vault.getAmount(_hashkey) <= 0 ? false : true);
        totalBalance = totalBalance.sub(refundAmount);

        uint256 _hours = (block.timestamp.sub(vault.getTimestamp(_hashkey))).div(3600);
        tokenManager.sendBonus(refundAmount, _hours, vault.getSender(_hashkey), msg.sender);
        
        emit Withdrawal(_commitment, _fee, refundAmount, block.timestamp);
    }

    function _processWithdraw(address payable _recipient, address _relayer, uint256 _fee, uint256 _refund) internal;
    function _safeErc20Transfer(address _to, uint256 _amount) internal;
    
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
        require(vault.getStatus(_oldHashKey), "Old commitment can not find");
        require(!vault.getStatus(_newHashKey), "The new commitment has been submitted or used out");
        require(vault.getCanEndorse(_oldHashKey), "Old commitment can not endorse");
        require(vault.getAmount(_oldHashKey) > 0, "No balance amount of this proof");
        uint256 refundAmount = _amount < vault.getAmount(_oldHashKey) ? _amount : vault.getAmount(_oldHashKey); //Take all if _refund == 0
        require(refundAmount > 0, "Refund amount can not be zero");

        if(_effectiveTime > 0 && block.timestamp >= vault.getEffectiveTime(_oldHashKey)) vault.setEffectiveTime(_oldHashKey,  _effectiveTime); // Effective
        else vault.setEffectiveTime(_newHashKey, vault.getEffectiveTime(_oldHashKey)); // Not effective
        
        vault.setStatus(_newHashKey, true);
        vault.setAmount(_newHashKey, refundAmount);
        vault.setSender(_newHashKey, msg.sender);
        vault.setTimestamp(_newHashKey, block.timestamp);
        vault.setCanEndorse(_newHashKey, false);
        vault.setLockable(_newHashKey, true);
        
        vault.setAmount(_oldHashKey, vault.getAmount(_oldHashKey).sub(refundAmount));
        vault.setStatus(_oldHashKey, vault.getAmount(_oldHashKey) <= 0 ? false : true);

        emit Withdrawal(_oldCommitment,  0, refundAmount, block.timestamp);
        emit Deposit(msg.sender, _newHashKey, refundAmount, block.timestamp);
    }
    
    /** @dev whether a note is already spent */
    function isSpent(bytes32 _hashkey) public view returns(bool) {
        return vault.getAmount(_hashkey) == 0 ? true : false;
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
    
    function setMinReplyHours(uint256 _hours) external nonReentrant onlyOperator {
        minReplyHours = _hours;
    }

    /** @dev lock commitment, this operation can be only called by note holder */
    function lockERC20Batch (
        bytes32             _hashkey,
        uint256             _refund,
        string   calldata   _description,
        uint256             _replyHours
    ) external payable nonReentrant {
        _lock(_hashkey, _refund, _description, _replyHours);
    }
    
    function _lock(
        bytes32 _hashkey,
        uint256 _refund,
        string memory _description,
        uint256 _replyHours
    ) internal {
        require(msg.sender == vault.getSender(_hashkey), 'Locker must be sender');
        require(vault.getLockable(_hashkey), 'This commitment must be lockable');
        require(vault.getAmount(_hashkey) >= _refund, 'Balance amount must be enough');
        require(_replyHours >= minReplyHours, 'The reply days less than minReplyHours');

        lockReason[_hashkey] = LockReason(
            _description, 
            1,
            block.timestamp,
            _replyHours * 3600 + block.timestamp,
            _refund == 0 ? vault.getAmount(_hashkey) : _refund,
            msg.sender,
            false,
            false,
            false
        );
    }
    
    function getLockReason(bytes32 _hashkey) public view returns(
        string memory   description, 
        uint8           status, 
        uint256         datetime, 
        uint256         replyDeadline,
        uint256         currentTime,
        uint256         refund, 
        address         locker, 
        bool            recipientAgree,
        bool            senderAgree,
        bool            toCouncil
    ) {
        LockReason memory data = lockReason[_hashkey];
        return (
            data.description, 
            data.status, 
            data.datetime, 
            data.replyDeadline,
            block.timestamp,
            data.refund, 
            data.locker, 
            data.recipientAgree,
            data.senderAgree,
            data.toCouncil
        );
    }
    
    function unlockByCouncil(bytes32 _hashkey, uint8 _result) external nonReentrant onlyCouncil {
        // _result = 1: sender win
        // _result = 2: recipient win
        require(_result == 1 || _result == 2);
        if(lockReason[_hashkey].status == 1 && lockReason[_hashkey].toCouncil) {
            lockReason[_hashkey].status = 3;
            // If the council decided to return back money to the sender
            uint256 councilFee = getJudgementFee(lockReason[_hashkey].refund);
            if(_result == 1) {
                _processWithdraw(lockReason[_hashkey].locker, councilAddress, councilFee, lockReason[_hashkey].refund);
                totalBalance = totalBalance.sub(lockReason[_hashkey].refund);
                vault.setAmount(_hashkey, vault.getAmount(_hashkey).sub(lockReason[_hashkey].refund));
                vault.setStatus(_hashkey, vault.getAmount(_hashkey) == 0 ? false : true);
            } else {
                lockReason[_hashkey].status = 3;
                _safeErc20Transfer(councilAddress, councilFee);
                totalBalance = totalBalance.sub(councilFee);
                vault.setAmount(_hashkey, vault.getAmount(_hashkey).sub(councilFee));
                vault.setStatus(_hashkey, vault.getAmount(_hashkey) == 0 ? false : true);
            }
        }
    }
    
    /**
     * recipient should agree to let sender refund, otherwise, will bring to the council to make a judgement
     * This is 1st step if dispute happend
     */
    function unlockByRecipent(bytes32 _hashkey, bytes32 _commitment, uint8 _status) external nonReentrant {
        bytes32 _recipientHashKey = getHashkey(bytes32ToString(_commitment));
        bool isSender = msg.sender == vault.getSender(_hashkey);
        bool isRecipent = _hashkey == _recipientHashKey;

        require(isSender || isRecipent, 'Must be called by recipient or original sender');
        require(_status == 1 || _status == 2);
        require(lockReason[_hashkey].status == 1);

        if(isSender && block.timestamp >= lockReason[_hashkey].datetime && _status != 3) {
            // Sender accept to keep cheque available
            lockReason[_hashkey].status = _status == 2 ? 4 : 1;
            lockReason[_hashkey].senderAgree = _status == 2;
            lockReason[_hashkey].toCouncil = _status == 1;
        } else if(isSender && block.timestamp >= lockReason[_hashkey].replyDeadline && _status == 3) {
            // Sender can refund after reply deadline
            lockReason[_hashkey].status = 5;
        } else if(isRecipent && block.timestamp >= lockReason[_hashkey].datetime && block.timestamp <= lockReason[_hashkey].replyDeadline ) {
            // recipient accept to refund back to sender
            lockReason[_hashkey].status = _status;
            lockReason[_hashkey].recipientAgree = _status == 2;
            lockReason[_hashkey].toCouncil = _status == 1;
        }
        // return back to sender
        if(lockReason[_hashkey].status == 2 || lockReason[_hashkey].status == 5) {
            _processWithdraw(vault.getSender(_hashkey), address(0x0), 0, lockReason[_hashkey].refund);
            totalBalance = totalBalance.sub(lockReason[_hashkey].refund);
            vault.setAmount(_hashkey, vault.getAmount(_hashkey).sub(lockReason[_hashkey].refund));
            vault.setStatus(_hashkey, vault.getAmount(_hashkey) == 0 ? false : true);
        }
    }
    
    /**
     * Cancel effectiveTime and change cheque to at sight
     */
    function changeToAtSight(bytes32 _hashkey) external nonReentrant returns(bool) {
        require(msg.sender == vault.getSender(_hashkey), 'Only sender can change this cheque to at sight');
        if(vault.getEffectiveTime(_hashkey) > block.timestamp) vault.setEffectiveTime(_hashkey, block.timestamp);
        return true;
    }
    
    function setCanEndorse(bytes32 _hashkey, bool status) external nonReentrant returns(bool) {
        require(msg.sender == vault.getSender(_hashkey), 'Only sender can change endorsable');
        vault.setCanEndorse(_hashkey, status);
    }

    function setLockable(bytes32 _hashKey, bool status) external nonReentrant returns(bool) {
        require(msg.sender == vault.getSender(_hashKey), 'Only sender can change lockable');
        require(vault.getLockable(_hashKey) && !status, 'Can only change from lockable to non-lockable');
        vault.setLockable(_hashKey, status);
        vault.setCanEndorse(_hashKey, true);
    }

    function getDepositDataByHashkey(bytes32 _hashkey) external view returns(uint256 effectiveTime, uint256 amount, bool lockable, bool canEndorse) {
        effectiveTime = vault.getEffectiveTime(_hashkey);
        amount = vault.getAmount(_hashkey);
        lockable = vault.getLockable(_hashkey);
        canEndorse = vault.getCanEndorse(_hashkey);
    }
    
    function updateCouncilJudgementFee(uint256 _fee, uint256 _rate) external nonReentrant onlyCouncil {
        councilJudgementFee = _fee;
        councilJudgementFeeRate = _rate;
    }
    
    function updateBonusTokenManager(address _BonusTokenManagerAddress) external nonReentrant onlyOperator {
        tokenManager = ShakerTokenManager(_BonusTokenManagerAddress);
    }
    
    function updateVault(address _vaultAddress) external nonReentrant onlyOperator {
        vaultAddress = _vaultAddress;
        vault = Vault(_vaultAddress);
    }
    
    function getJudgementFee(uint256 _amount) internal view returns(uint256) {
        return _amount * councilJudgementFeeRate / 10000 + councilJudgementFee;        
    }
}
