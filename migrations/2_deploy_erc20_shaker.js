/* global artifacts */
require('dotenv').config({ path: '../.env' })
const Token = artifacts.require('./Mocks/Token.sol')
const ERC20ShakerV2 = artifacts.require('ERC20ShakerV2')

module.exports = function(deployer, network, account) {
  return deployer.then(async () => {
    const { ERC20_TOKEN, FEE_ADDRESS } = process.env

    let token = ERC20_TOKEN
    if(token === '') token = (await deployer.deploy(Token)).address
    console.log('ERC20 Token', token);

    let shaker
    shaker = await deployer.deploy(
      ERC20ShakerV2,
      account,
      FEE_ADDRESS,
      token,
    )
    console.log('ERC20Shaker\'s address ', shaker.address)
  })
}
