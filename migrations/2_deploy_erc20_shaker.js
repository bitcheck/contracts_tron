/* global artifacts */
require('dotenv').config({ path: '../.env' })
const Token = artifacts.require('./Mocks/Token.sol')
const ERC20ShakerV2 = artifacts.require('ERC20ShakerV2')
const SKRToken = artifacts.require('./Mocks/SKRToken.sol')
const ShakerTokenManager = artifacts.require('./Mocks/ShakerTokenManager.sol')

module.exports = function(deployer, network, account) {
  return deployer.then(async () => {
    const { ERC20_TOKEN, SHAKER_ADDRESS, FEE_ADDRESS, SKR_TOKEN, SKR_TOKEN_MANAGER } = process.env

    // Step 1: Deploy Test USDT, if on mainnet, set the real USDT address in .env
    let token = ERC20_TOKEN
    if(token === '') token = (await deployer.deploy(Token)).address
    console.log('Test USDT Token\'s address\n===> ', token);

    // Step 2: Deploy main shaker contract
    let shaker = SHAKER_ADDRESS
    if(shaker === '') {
      shaker = await deployer.deploy(
      ERC20ShakerV2,
      account,
      FEE_ADDRESS,
      token,
    )} else {
      shaker = await ERC20ShakerV2.deployed();
    }
    console.log('ERC20Shaker\'s address \n===> ', shaker.address)

    // Step 3: Deploy SKRToken Manager
    let skrTokenManager = SKR_TOKEN_MANAGER
    if(skrTokenManager === '') {
      skrTokenManager = await deployer.deploy(
      ShakerTokenManager, 
      shaker.address
    )} else {
      skrTokenManager = await ShakerTokenManager.deployed()
    }
    console.log('Shaker Token(SKR) Manager\'s address \n===> ', skrTokenManager.address)
    console.log('SKR Manager has bound ERC20 Shaker\'s address\n===> ', shaker.address)

    // Step 4: Deploy SKRToken
    let skrToken = SKR_TOKEN
    if(skrToken === '') {
      skrToken = await deployer.deploy(
      SKRToken, 
      skrTokenManager.address
    )}else {
      skrToken = await SKRToken.deployed();
    }
    console.log('SKR Token\'s address\n===> ', skrToken.address);
    console.log('SKR Token has bound Token Manager\'s address \n===> ', skrTokenManager.address);

    // Step 5: 将SKRToken合约地址回写到SKRTokenManager合约，以便manger合约调用SKRToken合约的mint方法。
    skrTokenManager = await ShakerTokenManager.deployed();
    await skrTokenManager.setTokenAddress(skrToken.address);
    console.log('Token Manager has bound SKR Token\'s address\n===> ', skrToken.address);

    // Step 6: 将Token Manager合约地址回写到主 Shaker 合约中，方法：updateSKRTokenManager
    shaker = await ERC20ShakerV2.deployed();
    await shaker.updateSKRTokenManager(skrTokenManager.address);
    console.log('ERC20 Shaker has bound Token Manager\'s address\n===> ', skrTokenManager.address);

    // Testing
    console.log('\n======测试======\n')
    skrToken = await SKRToken.deployed();
    const mintAmount = await skrTokenManager.getMintAmount(1000000000, 23);
    console.log('mint amount', mintAmount.toString());

    // 必须要从shaker合约调用，不能直接调用manager或者SKR代币合约，因为权限
    // const depositer = 'TTEfHuHTcuzh8EYKU94s4374JPat7NCNhx';
    // const withdrawer = 'TTJGwZbbkAT3NtEv14g88oNbmrgjsmNPAK';
    // const result = await shaker.sendBonusTest(1000000000, 23, depositer, withdrawer);
    // console.log('result', result)
    // console.log(account + ' 测试Mint数量', (await skrToken.balanceOf(account)).toString())
    // console.log(depositer + ' 测试Mint数量', (await skrToken.balanceOf(depositer)).toString())
    // const addr = 'TToFUXbkqVKgbqZWYykTBBigcBYYza8Hhp';
    // console.log(addr + ' 测试Mint数量', (await skrToken.balanceOf(addr)).toString())

    // console.log('totalSupply', (await skrToken.totalSupply()).toString());

    // token = await Token.deployed();
    // console.log(account + ' 收取费用', (await skrTokenManager.getFee(100000000)).toString())
  })
}
