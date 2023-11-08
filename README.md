# TokenPocket AA Core
## Overview

account abstraction core, include account, factory, paymaster..e.g.

ERC20 Paymaster is an ERC-4337 Paymaster contract by TokenPocket which is able to sponsor gas fees in exchange for ERC20 tokens. The contract uses an Oracle to fetch the latest token prices, power by ChainLink.

## Development setup

This repository uses hardhat for development, and assumes you have already installed hardhat.

### hardhat

[Hardhat](https://hardhat.org/) is used for gas metering and developing sdk. 

1. install dependencies

```
npm install
```

2. compile contracts

```
npx hardhat compile
```

3. deploy

```
npx hardhat run ./scripts/deploy.ts
```

optional: run test or run coverage

```
npx hardhat test
npx hardhat coverage
```

## Deployed Contracts

### Polygon Mainnet

- [AADeployer](https://polygonscan.com/address/0x5b9f54243A0efF729C5045f47b2da5Ed4800C571) 
  
tools for deploying the same contract address

- [Account abstraction Implementation](https://polygonscan.com/address/0xC9B6dFDC54Dd45958956fc65143a7B107CbC79Fe)


- [TokenPocket AA Factory](https://polygonscan.com/address/0x04DD294F3B3BB0137754cdfAb86761c2d87F54Ef)


- [TokenOraclePaymaster](https://polygonscan.com/address/0x49321c737A1Cf0c7a8b908ecB64812E98f9E2E63) 

uses an Oracle to fetch the latest token prices, power by [ChainLink Price Feed](https://polygonscan.com/address/0xAB594600376Ec9fD91F8e885dADF0CE036862dE0)

- [TokenPocketPaymaster](https://polygonscan.com/address/0xab3a6a007da66f255a9ee75bf1070590c2f20a20) 
  
any ERC20 token can be used to pay for gas