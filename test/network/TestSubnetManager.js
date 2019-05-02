const SubnetManager = artifacts.require("SubnetManager.sol");
const Subnet = artifacts.require("MarconiSubnet.sol");
const truffleAssert = require('truffle-assertions');
require('truffle-test-utils').init();

contract('SubnetManager', function ([account0, account1, account2]) {
    let networkManager;

    // constants used in test cases
    const PUBKEY_HASH_1 = "abc123";
    const MAC_HASH_1 = "111aaa";
    const PUBKEY_HASH_2 = "456xyz";
    const MAC_HASH_2 = "222bbb";

    beforeEach('setup contract for each test', async function () {
        networkManager = await SubnetManager.new();
    });

    it('has initialized', async function () {
        assert.equal(await networkManager.getUserCount(), 0);
        assert.equal(await networkManager.getNetworkCount(), 0);
    });

    it("deploy with less than 7 mil gas", async () => {
        let receipt = await web3.eth.getTransactionReceipt(networkManager.transactionHash);
        assert.isBelow(receipt.gasUsed, 7000000);
    });

    it('register user', async function () {
        let registerEvent = await networkManager.registerUser(PUBKEY_HASH_1, MAC_HASH_1);
        assert.web3Event(registerEvent, {
            event: 'UserRegistered',
            args: {
                __length__: 2,
                0: PUBKEY_HASH_1,
                pubKeyHash: PUBKEY_HASH_1,
                1: MAC_HASH_1,
                macHash: MAC_HASH_1
            }
        }, 'UserRegistered event is emitted');
        assert.equal(await networkManager.getUserCount(), 1);

        registerEvent = await networkManager.registerUser(PUBKEY_HASH_2, MAC_HASH_2);
        assert.web3Event(registerEvent, {
            event: 'UserRegistered',
            args: {
                __length__: 2,
                0: PUBKEY_HASH_2,
                pubKeyHash: PUBKEY_HASH_2,
                1: MAC_HASH_2,
                macHash: MAC_HASH_2
            }
        }, 'UserRegistered event is emitted');
        assert.equal(await networkManager.getUserCount(), 2);
    });

    it('get user MAC hash', async function () {
        await networkManager.registerUser(PUBKEY_HASH_1, MAC_HASH_1);
        await networkManager.registerUser(PUBKEY_HASH_2, MAC_HASH_2);

        assert.equal(await networkManager.getUserMacHash(PUBKEY_HASH_1), MAC_HASH_1);
        assert.equal(await networkManager.getUserMacHash(PUBKEY_HASH_2), MAC_HASH_2);
    });

    it('create networks', async function () {
        await addNewNetworks();

        // verify the network contract from account0
        let networkContractAddress = await networkManager.networks(0);
        let networkContract = new Subnet(networkContractAddress);
        assert.equal(await networkContract.getPeerCount(), 0);
        assert.equal(await networkContract.id(), 0);
        assert.equal(await networkContract.admin(), account0);

        // add a peer to the network and verify
        let addPeerEvent = await networkContract.addPeer(PUBKEY_HASH_1);
        assert.web3Event(addPeerEvent, {
            event: 'PeerAdded',
            args: {
                __length__: 2,
                0: 0,
                networkId: 0,
                1: PUBKEY_HASH_1,
                pubKeyHash: PUBKEY_HASH_1
            }
        }, 'PeerAdded event is emitted');
        assert.equal(await networkContract.getPeerCount(), 1);

        // verify the network contract from account1
        networkContractAddress = await networkManager.networks(1);
        networkContract = new Subnet(networkContractAddress);
        assert.equal(await networkContract.getPeerCount(), 0);
        assert.equal(await networkContract.id(), 1);
        assert.equal(await networkContract.admin(), account1);
    });

    it('delete networks', async function () {
        await addNewNetworks();

        // attempt to delete network from non-admin should fail
        try {
            await networkManager.deleteNetwork(0, {from: account2});
            assert.fail("delete network should have thrown exception");
        } catch (error) {
            assert(error.toString().includes('VM Exception'), error.toString());
        }
        assert.equal(await networkManager.getNetworkCount(), 2);

        // delete the network from account0
        let deleteNetworkEvent = await networkManager.deleteNetwork(0, {from: account0});
        assert.web3Event(deleteNetworkEvent, {
            event: 'NetworkDeleted',
            args: {
                __length__: 2,
                0: 0,
                networkId: 0,
                1: account0,
                admin: account0
            }
        }, 'NetworkDeleted event is emitted');
        assert.equal(await networkManager.getNetworkCount(), 1);

        // delete the network from account1
        deleteNetworkEvent = await networkManager.deleteNetwork(1, {from: account1});
        assert.web3Event(deleteNetworkEvent, {
            event: 'NetworkDeleted',
            args: {
                __length__: 2,
                0: 1,
                networkId: 1,
                1: account1,
                admin: account1
            }
        }, 'NetworkDeleted event is emitted');
        assert.equal(await networkManager.getNetworkCount(), 0);
    });

    // helper function for adding new networks
    async function addNewNetworks() {
        let createNetworkEvent = await networkManager.createNetwork({from: account0});
        assert.web3Event(createNetworkEvent, {
            event: 'NetworkCreated',
            args: {
                __length__: 3,
                0: 0,
                networkId: 0,
                1: await networkManager.networks(0),
                networkContract: await networkManager.networks(0),
                2: account0,
                admin: account0
            }
        }, 'NetworkCreated  event is emitted');
        assert.equal(await networkManager.getNetworkCount(), 1);

        // create a contract by account1 and verify the transaction
        createNetworkEvent = await networkManager.createNetwork({from: account1});
        assert.web3Event(createNetworkEvent, {
            event: 'NetworkCreated',
            args: {
                __length__: 3,
                0: 1,
                networkId: 1,
                1: await networkManager.networks(1),
                networkContract: await networkManager.networks(1),
                2: account1,
                admin: account1
            }
        }, 'NetworkCreated event is emitted');
        assert.equal(await networkManager.getNetworkCount(), 2);
    }

});