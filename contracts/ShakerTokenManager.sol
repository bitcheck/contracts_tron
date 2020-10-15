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

import "./Mocks/SKRToken.sol";
// import "../ERC20/SKRToken.sol";
import "./ReentrancyGuard.sol";

// import "./SafeMath.sol";

/**
 * The bonus will calculated with 5 factors:
 * 1- Base bonus factor. This is base bonus factor, here we set it as 0.05
 * 2- Amount after exponent. This will reduce the weight of whale capital. Here we set it as 2/3. That means if somebody deposit 100,000, will just caculatd busnus 
 *    according to 100,000 ** (2/3) = 2154.435
 * 3- Hours factor between Deposit Withdraw. This is let the people store the money in contract longer. 
 *    If below 1 hour, there will be no bonus token.
 *    from 1-24 hours, the factor is 0.05; 24-48 hours, factor is 0.15, etc.
 *    This factor will be modified by council according to the market.
 * 4- Stage factor: If total mint token is 300,000, we will devided it into several stages. Each stage has special bonus times. Ex. if stage factor is 5, 
 *    means in this stage, miner will get 5 times than normal.
 * 5- Price elastical factor. We want the mint quantity for each deposit can be different under different market. If the price is higher than normal, the factor will 
 *    become smaller automaticly, and if the price go down, the factor will become smaller also. It is a Gaussian distribution, and the average price (normal price) 
 *    is fee of deposit and withdrawal.
 * 
 * So the bonus amount will be:
 * Bonus amount = Amount after exponent * Base bonus factor * hours factor * stage factor * price elastical factor.
 * 
 * In this version, we will keep price elastical factor as 1.
 * 
 */
contract ShakerTokenManager is ReentrancyGuard {
    using SafeMath for uint256;
    
    uint256 public bonusTokenDecimals = 6; // bonus token decimals
    uint256 public depositTokenDecimals = 6; // deposit and withdrawal token decimals
    uint256 public baseFactor = 50; // 50 means 0.05
    uint256[] public intervalOfDepositWithdraw = [1, 24, 48, 96, 192, 384, 720]; // hours of inverval between deposit and withdraw
    uint256[] public intervalOfDepositWithdrawFactor = [5000, 15000, 16800, 20600, 28600, 45500, 81500]; // 5000 will be devided by 1e5, means 0.05
    uint256[] public stageFactors = [5000, 2500, 1250]; // Stage factor, 5000 means 5, 2500 means 2.5, etc.
    uint256 public eachStageAmount = 1e11; // Each stage amount, if 100000, this amount will be 1e11 (including decimals)
    uint256[] public exponent = [2, 3];// means 2/3
    uint256 public feeRate = 16667;// 16.67 will be 16667
    uint256 public minChargeFeeAmount = 500 * 10 ** depositTokenDecimals;// Below this amount, will only charge  very special fee, like zero
    uint256 public minChargeFee = 0; // min amount of special charge.
    uint256 public minChargeFeeRate = 10; // percent rate of special charge, if need to charge 0.1%, this will be set 10
    uint256 public minMintAmount = 500 * 10 ** depositTokenDecimals;
    uint256 public taxRate = 500;// means 5%
    address public taxBereauAddress; // address to get tax
    uint256 public depositerShareRate = 5000; // depositer and withdrawer will share the bonus, this rate is for sender(depositer). 5000 means 0.500, 50%;
    
    address public operator;
    address public shakerContractAddress;
    address public tokenAddress;
    
    SKRToken public token = SKRToken(tokenAddress);
    
    modifier onlyOperator {
        require(msg.sender == operator, "Only operator can call this function.");
        _;
    }

    modifier onlyShaker {
        require(msg.sender == shakerContractAddress, "Only shaker contract can call this function.");
        _;
    }
    
    constructor(address _shakerContractAddress) public {
        operator = msg.sender;
        taxBereauAddress = msg.sender;
        shakerContractAddress = _shakerContractAddress;
    }
    
    function sendBonus(uint256 _amount, uint256 _hours, address _depositer, address _withdrawer) external nonReentrant onlyShaker returns(bool) {
        uint256 mintAmount = this.getMintAmount(_amount, _hours);
        uint256 tax = mintAmount.mul(taxRate).div(10000);
        uint256 notax = mintAmount.sub(tax);
        token.mint(_depositer, (notax.mul(depositerShareRate).div(10000)));
        token.mint(_withdrawer, (notax.mul(uint256(10000).sub(depositerShareRate)).div(10000)));
        token.mint(taxBereauAddress, tax);
        return true;
    }
    
    function burn(uint256 _amount, address _from) external nonReentrant onlyShaker returns(bool) {
        token.burn(_from, _amount);
        return true;
    }
    
    function getMintAmount(uint256 _amount, uint256 _hours ) external view returns(uint256) {
        // return back bonus token amount with decimals
        require(_amount < 1e18);
        if(_amount <= minMintAmount) return 0;
        uint256 amountExponented = getExponent(_amount);
        uint256 stageFactor = getStageFactor();
        uint256 intervalFactor = getIntervalFactor(_hours);
        uint256 priceFactor = getPriceElasticFactor();
        return amountExponented.mul(priceFactor).mul(baseFactor).mul(intervalFactor).mul(stageFactor).div(1e11);
    }
    
    function getFee(uint256 _amount) external view returns(uint256) {
        // return fee amount, including decimals
        require(_amount < 1e18);
        if(_amount <= minChargeFeeAmount) return getSpecialFee(_amount);
        uint256 amountExponented = getExponent(_amount);
        return amountExponented.mul(feeRate).div(1e5);
    }
    
    function getExponent(uint256 _amount) internal view returns(uint256) {
        // if 2000, the _amount should be 2000 * 10**decimals, return back 2000**(2/3) * 10**decimals
        if(_amount > 1e18) return 0;
        uint256 e = nthRoot(_amount, exponent[1], bonusTokenDecimals, 1e18);
        return e.mul(e).div(10 ** (bonusTokenDecimals + depositTokenDecimals * exponent[0] / exponent[1]));
    }
    
    function getStageFactor() internal view returns(uint256) {
        uint256 tokenTotalSupply = getTokenTotalSupply();
        uint256 stage = tokenTotalSupply.div(eachStageAmount); // each 100,000 is a stage
        return stageFactors[stage > 2 ? 2 : stage];
    }
    

    function getIntervalFactor(uint256 _hours) internal view returns(uint256) {
        uint256 id = intervalOfDepositWithdraw.length - 1;
        for(uint8 i = 0; i < intervalOfDepositWithdraw.length; i++) {
            if(intervalOfDepositWithdraw[i] > _hours) {
                id = i == 0 ? 999 : i - 1;
                break;
            }
        }
        return id == 999 ? 0 : intervalOfDepositWithdrawFactor[id];
    }
    
    // For tesing, Later will update ######
    function getPriceElasticFactor() internal pure returns(uint256) {
        return 1;
    }

    function getTokenTotalSupply() public view returns(uint256) {
        return token.totalSupply();
    }
    
    function getSpecialFee(uint256 _amount) internal view returns(uint256) {
        return _amount.mul(minChargeFeeRate).div(10000).add(minChargeFee);        
    }
    // calculates a^(1/n) to dp decimal places
    // maxIts bounds the number of iterations performed
    function nthRoot(uint _a, uint _n, uint _dp, uint _maxIts) internal pure returns(uint) {
        assert (_n > 1);

        // The scale factor is a crude way to turn everything into integer calcs.
        // Actually do (a * (10 ^ ((dp + 1) * n))) ^ (1/n)
        // We calculate to one extra dp and round at the end
        uint one = 10 ** (1 + _dp);
        uint a0 = one ** _n * _a;

        // Initial guess: 1.0
        uint xNew = one;
        uint x;
        uint iter = 0;
        while (xNew != x && iter < _maxIts) {
            x = xNew;
            uint t0 = x ** (_n - 1);
            if (x * t0 > a0) {
                xNew = x - (x - a0 / t0) / _n;
            } else {
                xNew = x + (a0 / t0 - x) / _n;
            }
            ++iter;
        }

        // Round to nearest in the last dp.
        return (xNew + 5) / 10;
    }
    
    function setStageFactors(uint256[] calldata _stageFactors) external onlyOperator {
        stageFactors = _stageFactors;
    }
    
    function setBaseFactor(uint256 _baseFactor) external onlyOperator {
        baseFactor = _baseFactor;
    }
    
    function setBonusTokenDecimals(uint256 _decimals) external onlyOperator {
        bonusTokenDecimals = _decimals;
    }
    
    function setDeositTokenDecimals(uint256 _decimals) external onlyOperator {
        depositTokenDecimals = _decimals;
    }

    function setTokenAddress(address _address) external onlyOperator {
        tokenAddress = _address;
        token = SKRToken(tokenAddress);
    }
    
    function setShakerContractAddress(address _shakerContractAddress) external onlyOperator {
        shakerContractAddress = _shakerContractAddress;
    }
    
    function setExponent(uint256[] calldata _exp) external onlyOperator {
        exponent = _exp;
    }
    
    function setEachStageAmount(uint256 _eachStageAmount) external onlyOperator {
        eachStageAmount = _eachStageAmount;
    }

    function setMinChargeFeeParams(uint256 _maxAmount, uint256 _minFee, uint256 _feeRate) external onlyOperator {
        minChargeFeeAmount = _maxAmount;
        minChargeFee = _minFee;
        minChargeFeeRate = _feeRate;
    }
    
    function setMinMintAmount(uint256 _amount) external onlyOperator {
        minMintAmount = _amount;
    }
    
    function setFeeRate(uint256 _feeRate) external onlyOperator {
        feeRate = _feeRate;
    }
    
    function setTaxBereauAddress(address _taxBereauAddress) external onlyOperator {
        taxBereauAddress = _taxBereauAddress;
    }
    
    function setTaxRate(uint256 _rate) external onlyOperator {
        taxRate = _rate;
    }
    
    function updateOperator(address _newOperator) external onlyOperator {
        operator = _newOperator;
    }
        
}