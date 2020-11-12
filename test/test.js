require('dotenv').config()

const TronWeb = require('tronweb')

// Connect to shasta testnet
// const privateKey = process.env.PRIVATE_KEY_SHASTA;
// const HttpProvider = TronWeb.providers.HttpProvider;
// const fullNode = new HttpProvider("https://api.shasta.trongrid.io");
// const solidityNode = new HttpProvider("https://api.shasta.trongrid.io");
// const eventServer = new HttpProvider("https://api.shasta.trongrid.io");
// const tronWeb = new TronWeb(
//   fullNode,
//   solidityNode,
//   eventServer,
//   privateKey
// );


// Connect to local tronquickstart node
const privateKey = process.env.PRIVATE_KEY_DEVELOPMENT;
const tronWeb = new TronWeb(
    "http://127.0.0.1:9090",
    "http://127.0.0.1:9090",
    "http://127.0.0.1:9090",
    privateKey,
)

const contractAddress = '41da24a55b3f83193fb9895cbe18e8652ed3ebb08c';
const commitment = '0x1ae657127872543e38148c602176b87ac68ef3958e5ef7c1d007bc07ee9772dd';

/**
 * 基本函数 
 */
const address = tronWeb.address.fromPrivateKey(privateKey);
console.log(address)
const addressHex = tronWeb.address.toHex(address);
console.log(addressHex);
// const addressBase64 = tronWeb.address.fromHex(addressHex);
// console.log(addressBase64);

// const contract = tronWeb.contract().at(contractAddress);
// console.log(contract)

// const trx = tronWeb.fromSun('10000000');
// console.log(trx);
// console.log(tronWeb.toSun(trx));

// const event = tronWeb.getEventByTransactionID('')
// const event = tronWeb.getEventResult(contractAddress, {}, callback);

// console.log(tronWeb.isAddress(address))
// console.log(isConnected())

// tronWeb.setAddress(address);
// console.log(tronWeb.defaultAddress);

// tronWeb.setPrivateKey(privateKey);
// console.log(tronWeb.defaultPrivateKey);

// console.log(tronWeb.sha3("Jacky Gu"))

// const strHex = tronWeb.fromAscii("guqianfeng");
// console.log(strHex);
// console.log(tronWeb.toAscii(strHex))

// const value = tronWeb.toBigNumber('200000000000000000000001');
// console.log(value)
// console.log(value.toNumber())

// const dec2hex = tronWeb.fromDecimal(1000000);
// console.log(dec2hex)
// const hex2dec = tronWeb.toDecimal(dec2hex);
// console.log(hex2dec)


/**
 * 账户相关 tronweb.trx 类
 */
// tronWeb.trx.getAccount(address).then(result => console.log('account details', result))

// tronWeb.trx.getAccountResources(address).then(result => console.log('account resources', result))

// tronWeb.trx.getBalance(address).then(result => console.log('balance', result));

// tronWeb.trx.getCurrentBlock().then(result => console.log('current block', result));

// tronWeb.trx.getBandwidth(address).then(result => console.log('bandwidth', result));

// tronWeb.trx.getBlock().then(result => console.log('block', result));

// tronWeb.trx.getContract(contractAddress).then(result => console.log('contract', result));

// tronWeb.trx.sendTransaction("TMdumsJQmXEn2zMGo4SGwCYvN7teXn6CJm", 1e6, privateKey).then(result => console.log('SendTransaction', result));

// tronWeb.trx.sendToken("TMdumsJQmXEn2zMGo4SGwCYvN7teXn6CJm", 1000, '100010', privateKey);

// sendRawTransactino();

addResource();

// tronWeb.trx.listTokens(10, 0).then(result => console.log('token list', result));

// getCallResult();

// getSend();

async function getCallResult() {
  let contract = await tronWeb.contract().at('41cdf5f8fc14dc967035d667488da5729d6220aa75');
  const commitment = '0x0101019a775c1d099d855751661df378b81411672cb926efc1ac79b22626f323'
  console.log(commitment);
  let result = await contract.bytes32ToString(commitment).call();
  console.log(result);
}

async function getSend() {
  let contract = await tronWeb.contract().at('41651596a91962a3b8b7e5d7cede0e3e732a3dc2b6');
  await contract.setSender().send();
  let result = await contract.getSender().call();
  console.log(result);
}
async function isConnected() {
  return await tronWeb.isConnected();
}

async function addResource() {
  const tradeobj = await freezeBalance(0); // 0- bandwidth, 1- ENERGY
  const signedtxn = await tronWeb.trx.sign(tradeobj, privateKey);
  const receipt = await tronWeb.trx.sendRawTransaction(signedtxn);
  console.log('receipt', receipt);
}

async function sendRawTransactino() {
  // const tradeobj = await createAssetObject();
  const tradeobj = await triggerSmartContractSet();
  // const tradeobj = await getHash();
  console.log('raw_data', JSON.stringify(tradeobj.transaction.raw_data))
  // const tradeobj = await triggerSmartContractGet();
  const signedtxn = await tronWeb.trx.sign(tradeobj.transaction, privateKey);
  // console.log('signed Tx', signedtxn)
  const receipt = await tronWeb.trx.sendRawTransaction(signedtxn);
  console.log('receipt', receipt);
}

async function createAssetObject() {
  const token = {
    name : "Test_USDT",//token名称,string格式
    abbreviation : "USDT",//token简称,  string格式
    description : "This is USDT for testing",//Token 说明,  string格式
    url : "www.tether.com",//Token 发行方的官网，string格式
    totalSupply : 10000000000000,//Token发行总量，按照精度
    trxRatio : 1, // 定义token和trx的最小单位兑换比
    tokenRatio : 1, // 定义token和trx的最小单位兑换比
    saleStart : 1602334351000,//开启时间，必须比当前时间晚
    saleEnd :   1681047110000,//结束时间
    freeBandwidth : 0, // 是Token的总的免费带宽 
    freeBandwidthLimit : 0, // 是每个token拥护者能使用本token的免费带宽 
    frozenAmount : 0, //是token发行者可以在发行的时候指定冻结的token的数量
    frozenDuration : 0, // 是token发行者可以在发行的时候指定冻结的token的时间
    precision : 6,//发行token的精度
    permission_id : 1//可选用于多重签名
  }
  try {
    return await tronWeb.transactionBuilder.createToken(token, address);
  } catch (err) {
    console.log(err);
  }
}

async function sendTrx() {
  return await tronWeb.transactionBuilder.sendTrx("TMdumsJQmXEn2zMGo4SGwCYvN7teXn6CJm", 1500000, address);
}

async function sendToken() {
  return await tronWeb.transactionBuilder.sendToken('TMdumsJQmXEn2zMGo4SGwCYvN7teXn6CJm', 10000000, '1000001', address);
}

async function triggerSmartContractSet() {
  // 创建一个未签名的调用智能合约的交易对象
  const org = commitment + '0x' + tronWeb.address.toHex(address).substring(2);
  console.log(org);
  const keccak = tronWeb.sha3(org);
  console.log('keccak', keccak);
  // 0xd752eb9a775c1d099d855751661df378b81411672cb926efc1ac79b22626f323
  const options = {
    feeLimit:100000000,
  };
  const parameter = [{
      type: 'bytes32', 
      value: keccak
    }, {
      type: 'uint256',
      value: 300000
    }
  ];
  const transaction = await tronWeb.transactionBuilder.triggerSmartContract(contractAddress, "set(bytes32,uint256)", options, parameter, address);
  return transaction;
}

async function getHash() {
  console.log('commitment', commitment)
  const org = commitment + '0x' + tronWeb.address.toHex(address).substring(2);
  console.log(org);
  const keccak = tronWeb.sha3(org);
  console.log('keccak', keccak);

  const parameter = [{
    type: 'string',
    value: commitment
  }];
  const transaction = await tronWeb.transactionBuilder.triggerSmartContract(contractAddress, "getHash(string)", {feeLimit: 1e8}, parameter, address);
  return transaction;
}

async function triggerSmartContractGet() {
  // 创建一个未签名的调用智能合约的交易对象
  var options = {
    feeLimit:100000000,
  };
  const amount = 300000;
  const commitment = '0x1ae657127872543e38148c602176b87ac68ef3958e5ef7c1d007bc07ee9772dd';

  const parameter = [{
      type: 'uint256',
      value: amount
    }, {
      type: 'string', 
      value: commitment
    }
  ];
  const transaction = await tronWeb.transactionBuilder.triggerSmartContract(contractAddress, "get(uint256,string)", options, parameter, address);
  return transaction;
}

async function getContract(contractAddress) {
  return await tronWeb.contract().at(contractAddress);
}

async function freezeBalance(type) {
  return await tronWeb.transactionBuilder.freezeBalance(tronWeb.toSun(1000), 3, type === 0 ? "BANDWIDTH" : "ENERGY", address, address);
}