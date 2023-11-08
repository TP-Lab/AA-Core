import {HardhatUserConfig} from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter";
import {HttpNetworkAccountsUserConfig} from "hardhat/src/types/config";

const config: HardhatUserConfig = {
    paths: {
        sources: "./contracts/core"
    },
    solidity: {
        version: "0.8.19",
        settings: {
            evmVersion: "paris",
            optimizer: {
                enabled: true,
                runs: 1000
            }
        }
    },
    defaultNetwork: "goerli",
    networks: {
        hardhat: {},
        ganache: {
            gas: "auto",
            gasPrice: "auto",
            gasMultiplier: 1,
            url: "http://127.0.0.1:7509",
            timeout: 5000,
            accounts: [
                "0xa796f829b54eeb1866f85dce12fca9ed49eee8c33ff453d0d794bdf61ac878b5",
                "0x855e884e693032d5c9e9f045b2215000387ccb55056b8ffecb52a19394842cd9"
            ]
        },
        polygon: {
            chainId: 137,
            gas: "auto",
            gasPrice: "auto",
            gasMultiplier: 1,
            url: "https://rpc.ankr.com/polygon",
            timeout: 50000,
            accounts: []
        },
        goerli: {
            chainId: 5,
            gas: "auto",
            gasPrice: 1000000000,
            gasMultiplier: 1,
            url: "https://rpc.ankr.com/eth_goerli",
            timeout: 20000,
            accounts: []
        }
    },
    gasReporter: {
        enabled: false
    }
};

export default config;
