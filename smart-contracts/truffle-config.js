const HDWalletProvider = require('@truffle/hdwallet-provider');

const MNEMONIC = process.env.PROTOTYPE_BR_KEY || '';
const INFURA_KEY = process.env.PROTOTYPE_BR_INFURA_KEY || '';
const ETHERSCAN_KEY = process.env.ETHERSCAN_KEY || '';

module.exports = {
    // N.B - this seems to crash solidity-coverage so its disabled
    // mocha: {
    //     reporter: 'eth-gas-reporter',
    //     reporterOptions : {
    //         currency: 'GBP',
    //         gasPrice: 5
    //     }
    // },
    compilers: {
        solc: {
            version: '0.5.12',
            settings: {
                optimizer: {
                    enabled: true, // Default: false
                    runs: 200      // Default: 200
                },
            }
        }
    },
    networks: {
        development: {
            host: '127.0.0.1',
            port: 7545,
            gas: 6721975, // <-- Use this high gas value
            gasPrice: 1000000000,    // <-- Use this low gas price
            network_id: '*', // Match any network id
        },
        ganache: {
            host: '127.0.0.1',
            port: 7545,
            gas: 6721975, // <-- Use this high gas value
            gasPrice: 1000000000,    // <-- Use this low gas price
            network_id: '5777', // Match any network id
        },
        soliditycoverage: {
            host: "localhost",
            network_id: "*",
            port: 8555,         // <-- If you change this, also set the port option in .solcover.js.
            gas: 6721975, // <-- Use this high gas value
            gasPrice: 1000000000      // <-- Use this low gas price
        },
        rinkeby: {
            provider: function () {
                return new HDWalletProvider(MNEMONIC, `https://rinkeby.infura.io/v3/${INFURA_KEY}`);
            },
            network_id: 4,
            gas: 6000000,
            gasPrice: 25000000000, // 25 Gwei. default = 100 gwei = 100000000000
            skipDryRun: true
        },
        ropsten: {
            provider: function () {
                return new HDWalletProvider(MNEMONIC, `https://ropsten.infura.io/v3/${INFURA_KEY}`);
            },
            network_id: 3,
            gas: 7000000, // default = 4712388
            gasPrice: 25000000000, // 25 Gwei. default = 100 gwei = 100000000000
            skipDryRun: true
        },
        kovan: {
            provider: function () {
                return new HDWalletProvider(MNEMONIC, `https://kovan.infura.io/v3/${INFURA_KEY}`);
            },
            network_id: 42,
            gas: 7000000, // default = 4712388
            gasPrice: 12000000000, // 12 Gwei. default = 100 gwei = 100000000000
            skipDryRun: true
        },
        live: {
            provider: function () {
                return new HDWalletProvider(MNEMONIC, `https://mainnet.infura.io/v3/${INFURA_KEY}`);
            },
            network_id: 1,
            gas: 8000000,         // default = 4712388
            gasPrice: 7200000000, // default = 100 gwei = 100000000000
            timeoutBlocks: 200,   // # of blocks before a deployment times out  (minimum/default: 50)
            skipDryRun: true      // Skip dry run before migrations? (default: false for public nets )
        },
    },
    plugins: [
        'truffle-plugin-verify'
    ],
    verify: {
        preamble: "Author: Blockrocket.tech.\n"
    },
    api_keys: {
        etherscan: ETHERSCAN_KEY
    }
};