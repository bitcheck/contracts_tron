/* global artifacts */
require('dotenv').config({ path: '../.env' })
const Token = artifacts.require('./Mocks/Token.sol')
const ERC20ShakerV2 = artifacts.require('./ERC20ShakerV2')
const BTCHToken = artifacts.require('./Mocks/BTCHToken.sol')
const ShakerTokenManager = artifacts.require('./ShakerTokenManager.sol')
const DividendPool = artifacts.require('./DividendPool.sol');
const Vault = artifacts.require('./Vault.sol');
const Dispute = artifacts.require('./Dispute.sol');
const BCTToken = artifacts.require('./BCTToken.sol');
const TokenLocker = artifacts.require('./TokenLocker.sol');
const DisputeManager = artifacts.require('./DisputeManager.sol');

module.exports = function(deployer, network, account) {
  return deployer.then(async () => {
    const { ERC20_TOKEN, SHAKER_ADDRESS, FEE_ADDRESS, BTCH_TOKEN, BTCH_TOKEN_MANAGER, DIVIDEND_POOL, TAX_BEREAU, VAULT_ADDRESS, BCT_TOKEN, TOKEN_LOCKER, DISPUTE_ADDRESS, DISPUTE_MANAGER } = process.env
    const tmpAddress = FEE_ADDRESS; //部署合约时用于参数临时

    // Deploy Test USDT, if on mainnet, set the real USDT address in .env
    let token = ERC20_TOKEN
    if(token === '') token = (await deployer.deploy(Token)).address
    console.log('Test USDT Token\'s address\n===> ', token);

    // Vault contract
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

    // Dispute contract
    let dispute = DISPUTE_ADDRESS;
    if(dispute === '') {
      dispute = await deployer.deploy(
        Dispute
      )
    } else {
      dispute = await Dispute.deployed();
    }
    console.log('Disput\'s address \n===> ', dispute.address);

    // Deploy BTCHToken
    let btchToken = BTCH_TOKEN
    if(btchToken === '') {
      btchToken = await deployer.deploy(
        BTCHToken, 
        tmpAddress
      )
    }else {
      btchToken = await BTCHToken.deployed();
    }
    console.log('BTCH Token\'s address\n===> ', btchToken.address);

    // Deploy BCT Token
    let bctToken = BCT_TOKEN;
    if(bctToken === '') {
      bctToken = await deployer.deploy(
        BCTToken
      )
    } else {
      bctToken = await BCTToken.deployed();
    }
    console.log('BCT Token\'s address\n===> ', btchToken.address);

    // Deploy TokenLocker
    let tokenLocker = TOKEN_LOCKER;
    if(tokenLocker === '') {
      tokenLocker = await deployer.deploy(
        TokenLocker,
        btchToken.address,
        60,
        15552000 // 180days
      )
    } else {
      tokenLocker = await TokenLocker.deployed();
    }
    console.log('TokenLocker address\n===> ', tokenLocker.address);

    // Deploy dividend Pool
    let dividendPool = DIVIDEND_POOL;
    if(dividendPool === '') {
      dividendPool = await deployer.deploy(
        DividendPool,
        btchToken.address,
        token,
        FEE_ADDRESS
      );
    } else {
      dividendPool = await DividendPool.deployed();
    }
    console.log('DividendPool address \n===> ', dividendPool.address);

    // Deploy main shaker contract
    let shaker = SHAKER_ADDRESS
    if(shaker === '') {
      shaker = await deployer.deploy(
      ERC20ShakerV2,
      FEE_ADDRESS,  // commonWithdrawAddress
      token,        // USDT Token address
      vault.address, 
      dispute.address
    )} else {
      shaker = await ERC20ShakerV2.deployed();
    }
    console.log('ShakerV2\'s address \n===> ', shaker.address)

    // Dispute Manager contract
    let disputeManager = DISPUTE_MANAGER;
    if(disputeManager === '') {
      disputeManager = await deployer.deploy(
        DisputeManager,
        shaker.address,
        token,
        vault.address,
        dispute.address
      )
    } else {
      disputeManager = await DisputeManager.deployed();
    }
    console.log('Dispute Manager address \n===>', disputeManager.address);

    // Deploy BTCHToken Manager
    let btchTokenManager = BTCH_TOKEN_MANAGER
    if(btchTokenManager === '') {
      btchTokenManager = await deployer.deploy(
      ShakerTokenManager, 
      shaker.address,
      TAX_BEREAU,
      btchToken.address,
      bctToken.address,
      tokenLocker.address
    )} else {
      btchTokenManager = await ShakerTokenManager.deployed();
    }
    console.log('BitCheck Token(BTCH) Manager\'s address \n===> ', btchTokenManager.address)

    // 手动在网页端设置合约之间的勾稽关系
  })
}
