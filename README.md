# Project Structure

`/contracts` All contract code for Marconi and leveraged dependencies

    - Network.sol: Encapsulates a Marconi network, handling add/remove of peers.
    - NetworkManager.sol: Top level contract for managing all Marconi networks, handles the creation and deletion of networks.
    - Util.sol: Utility functions used by Network and NetworkManager.

`/migrations` Scripts specifying which contracts to deploy

`/test` Test scripts for the smart contracts

    - Network.js: Test the add/remove peer of a Marconi network
    - NetworkManager.js: Test the register/create/destroy logic of Marconi networks

`/truffle-js` Tells Truffle the blockchain env (e.g. local dev or a remote Meth)

`/get-deps.sh` Installs any npm packages needed to run the unit tests

# Quick Start
It can be quite painful to develop and test changes in a Smart Contract manually due to the need of bringing up a blockchain, funding test accounts, and copying bytecodes to deploy contracts, etc. Therefore, we have adopted Truffle as our development environment in order to iterate and move more quickly.

Truffle provides us with the following key benefits:
- automated deployment of contracts configurable via a deploy script
- write unit tests with Web3js
- compiling contracts with nested dependencies
- integrated debugger for stepping through contracts

### Install Truffle && Ganache
We are using truffle 5 as it provides better interfaces for writing unit tests via Web3js 1.0. Ganache is a tool allow us to easily spin up a private Ethereum chain locally.
```
npm install -g truffle
npm install -g ganache-cli
```

### Start Ganache with configured parameters
In GMeth we have increased the gas limit such that we can deploy larger contract and with higher gas limit than normal Ethereum chain. As a result, our contracts won't work with default gas limit and allowed contract size of Ethereum. Ganache give us a easy way to ignore those limits during testing.
```
ganache-cli --gasLimit=20000000 --allowUnlimitedContractSize
```

### Compile Smart Contracts
compile contracts that has changes:
```
truffle compile
```
re-compile all contracts:
```
truffle compile --all
```

### Run the unit tests
Our unit tests rely on a few node modules to run, the get_deps.sh script installs those for you. Make sure that Ganache is running as the unit tests will be executed there.
```
// install dependency packages
./get_deps.sh

// deploy all contracts including the library contracts
truffle migrate --network local

// run tests
truffle test --network local
```

### Deploying to GMeth
For integration testing, you'll likely want to deploy the contracts to a actual GMeth. Below are the steps on how to do it via Truffle:

1. "truffle compile" (compile the contracts)
2. run your geth console (make sure to specify --rpcport and --rpccorsdomain)
3. open truffle.js and update the network 'test' section according to your geth, fill in the hostname and rpcport
4. "truffle migrate --network test" (deploy the contracts to network 'test')
5. all the addresses of the deployed contracts should be printed by truffle, use them in web3js

# Useful commands in Web3js:
```
personal.unlockAccount(eth.accounts[0], "password");
```
```
var testContract = eth.contract(ABI_OF_CONTRACT)
var myContract = testContract.at("ADDRESS_OF_CONTRACT");
myContract.testFunction("blah blah", {from: eth.accounts[0], gas: 3000000});
```
# Useful commands when debugging in geth console:
```
eth.getBalance(eth.accounts[0])
eth.getBlock("pending").gasLimit
```

# Additional Resources on Truffle
https://truffleframework.com/docs/truffle/getting-started/using-truffle-develop-and-the-console
https://truffleframework.com/docs/truffle/testing/testing-your-contracts
https://truffleframework.com/docs/truffle/testing/writing-tests-in-javascript
