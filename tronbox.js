require('dotenv').config();
const port = process.env.HOST_PORT || 9090

module.exports = {
  networks: {
    mainnet: {
      // Don't put your private key here:
      privateKey: process.env.PRIVATE_KEY_MAINNET,
      /*
Create a .env file (it must be gitignored) containing something like

  export PRIVATE_KEY_MAINNET=4E7FECCB71207B867C495B51A9758B104B1D4422088A87F4978BE64636656243

Then, run the migration with:

  source .env && tronbox migrate --network mainnet

*/
      userFeePercentage: 100,
      feeLimit: 1e9,
      fullHost: 'https://api.trongrid.io',
      network_id: '1'
    },
    shasta: {
      privateKey: process.env.PRIVATE_KEY_SHASTA,
      userFeePercentage: 100,
      feeLimit: 1e8,      // 如果遇到缺乏Engergy无法部署，调高此参数，默认为1e8
      originEnergyLimit: 1e7,
      fullHost: 'https://api.shasta.trongrid.io',
      network_id: '2'
    },
    nile: {
      privateKey: process.env.PRIVATE_KEY_NILE,
      fullNode: 'https://api.nileex.io',
      solidityNode: 'https://api.nileex.io/walletsolidity',
      eventServer: 'https://event.nileex.io',
      network_id: '3'
    },
    development: {
      // For trontools/quickstart docker image
      privateKey: process.env.PRIVATE_KEY_DEVELOPMENT,
      userFeePercentage: 0,
      feeLimit: 1e9,
      fullHost: 'http://127.0.0.1:9090',
      network_id: '2000'
    },
    compilers: {
      solc: {
        version: '0.5.9',    // Fetch exact version from solc-bin (default: truffle's version)
        // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
        settings: {          // See the solidity docs for advice about optimization and evmVersion
          optimizer: {
            enabled: true,
            runs: 200
          },
          // evmVersion: "byzantium"
        }
      }
    }
  }
}
