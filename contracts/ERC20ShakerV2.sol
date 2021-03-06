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

import "./ShakerV2.sol";
import "./Mocks/IERC20.sol";

contract ERC20ShakerV2 is ShakerV2 {
  address public token;

  constructor(
    address _commonWithdrawAddress,
    address _tokenAddress,
    address _vaultAddress,
    address _disputeManagerAddress
  ) ShakerV2(msg.sender, _commonWithdrawAddress, _vaultAddress, _tokenAddress, _disputeManagerAddress) public {
    token = _tokenAddress;
  }

  function _processDeposit(uint256 _amount, address _to) internal {
    require(msg.value == 0, "ETH value is supposed to be 0 for ERC20 instance");
    IERC20(token).transferFrom(msg.sender, _to, _amount);
  }

  function _processWithdraw(address payable _recipient, address _relayer, uint256 _fee, uint256 _refund) internal {
    IERC20(token).transferFrom(vaultAddress, _recipient, _refund.sub(_fee));
    if(_fee > 0) IERC20(token).transferFrom(vaultAddress, _relayer, _fee);
  }

}
