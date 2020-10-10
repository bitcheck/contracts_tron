pragma solidity >=0.4.23 <0.6.0;

contract Test {
    
    mapping(bytes32 => uint256) private deposits;
    address public sender;

    function get(uint256 _amount, string calldata _commitment) external view returns(bool) {
        string memory commitAndTo = concat(_commitment, addressToString(msg.sender));
        bytes32 _hashkey = keccak256(abi.encodePacked(commitAndTo));
        return (deposits[_hashkey] >= _amount);
    }
    
    function getHash(string calldata _commitment) external view returns(string memory commitAndTo, bytes32 hashkey) {
        commitAndTo = concat(_commitment, addressToString(msg.sender));
        hashkey = keccak256(abi.encodePacked(commitAndTo));
    }
    
    function set(bytes32 _hashkey, uint256 _amount) external returns(bool) {
        deposits[_hashkey] = _amount;
        return true;
    }
    function setSender() external {
      sender = msg.sender;
    }
    function getSender() external view returns(bool, address, address) {
      return (sender == msg.sender, msg.sender, sender);
    }
    function concat(string memory _base, string memory _value)
        internal
        pure
        returns (string memory) {
        bytes memory _baseBytes = bytes(_base);
        bytes memory _valueBytes = bytes(_value);

        assert(_valueBytes.length > 0);

        string memory _tmpValue = new string(_baseBytes.length +
            _valueBytes.length);
        bytes memory _newValue = bytes(_tmpValue);

        uint i;
        uint j;

        for (i = 0; i < _baseBytes.length; i++) {
            _newValue[j++] = _baseBytes[i];
        }

        for (i = 0; i < _valueBytes.length; i++) {
            _newValue[j++] = _valueBytes[i];
        }

        return string(_newValue);
    }
    
    function addressToString(address _addr) internal pure returns(string memory) {
        bytes32 value = bytes32(uint256(_addr));
        bytes memory alphabet = "0123456789abcdef";
    
        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
        for (uint i = 0; i < 20; i++) {
            str[2+i*2] = alphabet[uint(uint8(value[i + 12] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(value[i + 12] & 0x0f))];
        }
        return string(str);
    }
        
    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
        uint8 i = 0;
        while(i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    function bytes32ToString1(bytes32 x) public pure returns (string memory) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        for (uint j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (uint j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }

}
