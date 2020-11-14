/* global artifacts */
require('dotenv').config({ path: '../.env' })
const Token = artifacts.require('./Mocks/Token.sol')
const ERC20ShakerV2 = artifacts.require('./ERC20ShakerV2')
const BTCHToken = artifacts.require('./Mocks/BTCHToken.sol')
const ShakerTokenManager = artifacts.require('./ShakerTokenManager.sol')
const DividendPool = artifacts.require('./DividendPool.sol');
const Vault = artifacts.require('./Vault.sol');

module.exports = function(deployer, network, account) {
  return deployer.then(async () => {
    const { ERC20_TOKEN, SHAKER_ADDRESS, FEE_ADDRESS, BTCH_TOKEN, BTCH_TOKEN_MANAGER, DIVIDEND_POOL, TAX_BEREAU, VAULT_ADDRESS } = process.env

    // Step 1: Deploy Test USDT, if on mainnet, set the real USDT address in .env
    let token = ERC20_TOKEN
    if(token === '') token = (await deployer.deploy(Token)).address
    console.log('Test USDT Token\'s address\n===> ', token);

    let vault = VAULT_ADDRESS
    if(vault === '') {
      vault = await deployer.deploy(
        Vault,
        ERC20_TOKEN
      )
    } else {
      vault = await Vault.deployed();
    }
    console.log('Vault\'s address \n===> ', vault.address);

    // Step 2: Deploy main shaker contract
    let shaker = SHAKER_ADDRESS
    if(shaker === '') {
      shaker = await deployer.deploy(
      ERC20ShakerV2,
      account,  // Operator
      FEE_ADDRESS,  // commonWithdrawAddress
      token,        // USDT Token address
      vault.address
    )} else {
      shaker = await ERC20ShakerV2.deployed();
    }
    await shaker.updateVault(vault.address);
    console.log('ShakerV2\'s address \n===> ', shaker.address)
    vault = await Vault.deployed();
    await vault.updateShakerAddress(shaker.address, 10000000 * 10e6); // Approve shaker contract to use vault

    // Step 3: Deploy BTCHToken Manager
    let btchTokenManager = BTCH_TOKEN_MANAGER
    if(btchTokenManager === '') {
      btchTokenManager = await deployer.deploy(
      ShakerTokenManager, 
      shaker.address,
      TAX_BEREAU
    )} else {
      btchTokenManager = await ShakerTokenManager.deployed();
    }
    console.log('BitCheck Token(BTCH) Manager\'s address \n===> ', btchTokenManager.address)
    console.log('BTCH Manager has bound ERC20 Shaker\'s address\n===> ', shaker.address)

    // Step 4: Deploy BTCHToken
    let btchToken = BTCH_TOKEN
    if(btchToken === '') {
      btchToken = await deployer.deploy(
      BTCHToken, 
      btchTokenManager.address
    )}else {
      btchToken = await BTCHToken.deployed();
    }
    console.log('BTCH Token\'s address\n===> ', btchToken.address);
    console.log('BTCH Token has bound Token Manager\'s address \n===> ', btchTokenManager.address);

    // Step 5: 
    btchTokenManager = await ShakerTokenManager.deployed();
    await btchTokenManager.setTokenAddress(btchToken.address);
    console.log('Token Manager has bound BTCH Token\'s address\n===> ', btchToken.address);

    // Step 6:
    await btchToken.updateAuthorizedContract(btchTokenManager.address);
    console.log('BTCH Token has updated authorized manager contract \n===> ', btchTokenManager.address);
    
    // Step 7: 
    shaker = await ERC20ShakerV2.deployed();
    await shaker.updateBonusTokenManager(btchTokenManager.address);
    console.log('Shaker has bound Token Manager\'s address\n===> ', btchTokenManager.address);
    await btchTokenManager.setShakerContractAddress(shaker.address);
    console.log('Token Manager has bound Shaker \'s address\n===> ', shaker.address);

    // Step 8:
    let dividendPool = DIVIDEND_POOL;
    if(dividendPool === '') {
      dividendPool = await deployer.deploy(
        DividendPool,
        btchToken.address,
        ERC20_TOKEN,
        FEE_ADDRESS     // Send dividend from this address
      )
    } else {
      dividendPool = await DividendPool.deployed();
      await dividendPool.updateTokenAddress(btchToken.address);
      await dividendPool.setDividentAddress(ERC20_TOKEN);
      await dividendPool.setFeeAddress(FEE_ADDRESS);
    }
    console.log('Dividend Pool\'s address\n===> ', dividendPool.address);
    console.log(`*** Please approve dividend pool contract ${dividendPool.address} to use 100000 USDT from fee account ${FEE_ADDRESS} MANULLY`);
    console.log(`approve(${dividendPool.address}, 100000000000)`);

    // Ajust params for Tron network
    btchTokenManager = await ShakerTokenManager.deployed();
    btchTokenManager.setMinChargeFeeParams(10000000 * 10e6, 0, 100);
    btchTokenManager.setMinMintAmount(10000000 * 10e6);

    // Testing
    console.log('\n====== TEST ======\n')
    shaker = await ERC20ShakerV2.deployed();
    const _feeAddress = await shaker.commonWithdrawAddress();
    const _managerAddress2 = await shaker.tokenManager();
    btchTokenManager = await ShakerTokenManager.deployed()
    const _shakerAddress = await btchTokenManager.shakerContractAddress();
    const _tokenAddress = await btchTokenManager.tokenAddress();
    btchToken = await BTCHToken.deployed();
    const _managerAddress = await btchToken.authorizedContract();
    dividendPool = await DividendPool.deployed();
    const _tokenAddress2 = await dividendPool.tokenAddress();
    const _dividentAddress = await dividendPool.dividentAddress();
    const _feeAddress2 = await dividendPool.feeAddress();

    console.log("Fee address in shaker: " + _feeAddress);
    console.log("Fee address in dividendPool: " + _feeAddress2);
    console.log("Token manager address in shaker: " + _managerAddress2);
    console.log("Token manager address in btchToken: " + _managerAddress);
    console.log("Shaker address in BTCH Token manager: " + _shakerAddress);
    console.log("Token address in BTCH Token manager: " + _tokenAddress);
    console.log("TokenAddress in dividendPool: " + _tokenAddress2);
    console.log("Dividend Token address in dividendPool: " + _dividentAddress);
  })
}
