const Network = artifacts.require("Network.sol");
const NetworkManager = artifacts.require("NetworkManager.sol");

contract('Network', function ([account0, account1]) {

    let network;
    let admin;

    // constants used in test cases
    const PUBKEY_HASH_1 = "abc123";
    const PUBKEY_HASH_2 = "456xyz";
    const PUBKEY_HASH_3 = "omg789";

    beforeEach('setup contract for each test', async function () {
        networkManager = await NetworkManager.new();
        network = await Network.new(0, account0, networkManager.address);
        admin = account0.toLowerCase();
    });

    it('has initialized', async function () {
        assert.equal(await network.getPeerCount(), 0);
        assert.equal(await network.active(), true);
    });

    it("deploy with less than 6 mil gas", async () => {
        let receipt = await web3.eth.getTransactionReceipt(network.transactionHash);
        assert.isBelow(receipt.gasUsed, 6000000);
    });

    it('check empty network', async function () {
        assert.equal(await network.getPeerCount(), 0);
        let networkManagerAddress = networkManager.address.toLowerCase()
        let jsonExpected = '{ "networkId": "0", "admin": "' + admin + '", "networkManager": "' + networkManagerAddress +'", "active": true, "peers": [] }';;
        assert.equal(await network.getDataJSON(), jsonExpected);
    });

    it('add peer', async function () {
        await addPeersOneAndTwo();

        // attempt to add the same peer should fail
        try {
            await network.addPeer(PUBKEY_HASH_2);
            assert.fail("add same peer should have thrown exception");
        } catch (error) {
            assert(error.toString().includes('VM Exception'), error.toString());
        }
        assert.equal(await network.getPeerCount(), 2);

        // add a peer from non-admin should fail
        try {
            await network.addPeer(PUBKEY_HASH_3, {from: account1});
            assert.fail("add peer from non-admin should have thrown exception");
        } catch (error) {
            assert(error.toString().includes('VM Exception'), error.toString());
        }
        assert.equal(await network.getPeerCount(), 2);
    });

    it('remove peer', async function () {
        await addPeersOneAndTwo();

        // remove a non-existing peer should fail
        try {
            await network.removePeer(PUBKEY_HASH_3);
            assert.fail("removing a non-existing peer should have thrown exception");
        } catch (error) {
            assert(error.toString().includes('VM Exception'), error.toString());
        }
        assert.equal(await network.getPeerCount(), 2);

        // remove a peer from non-admin should fail
        try {
            await network.removePeer(PUBKEY_HASH_1, {from: account1});
            assert.fail("removing a peer from non-admin should have thrown exception");
        } catch (error) {
            assert(error.toString().includes('VM Exception'), error.toString());
        }
        assert.equal(await network.getPeerCount(), 2);

        // remove the peers
        let removePeerEvent = await network.removePeer(PUBKEY_HASH_1);
        assert.web3Event(removePeerEvent, {
            event: 'PeerRemoved',
            args: {
                __length__: 2,
                0: 0,
                networkId: 0,
                1: PUBKEY_HASH_1,
                pubKeyHash: PUBKEY_HASH_1
            }
        }, 'PeerRemoved event is emitted');

        assert.equal(await network.getPeerCount(), 1);
        removePeerEvent = await network.removePeer(PUBKEY_HASH_2);
        assert.web3Event(removePeerEvent, {
            event: 'PeerRemoved',
            args: {
                __length__: 2,
                0: 0,
                networkId: 0,
                1: PUBKEY_HASH_2,
                pubKeyHash: PUBKEY_HASH_2
            }
        }, 'PeerRemoved event is emitted');
        assert.equal(await network.getPeerCount(), 0);
    });

    it('remove a peer and add it back', async function () {
        await addPeerOne();

        removePeerEvent = await network.removePeer(PUBKEY_HASH_1);
        assert.web3Event(removePeerEvent, {
            event: 'PeerRemoved',
            args: {
                __length__: 2,
                0: 0,
                networkId: 0,
                1: PUBKEY_HASH_1,
                pubKeyHash: PUBKEY_HASH_1
            }
        }, 'PeerRemoved event is emitted');
        assert.equal(await network.getPeerCount(), 0);

        await addPeerOne();
    });

    it('add peer relation', async function () {
        await addPeersOneAndTwo();

        let addPeerRelationEvent = await network.addPeerRelation(PUBKEY_HASH_1, PUBKEY_HASH_2);
        assert.web3Event(addPeerRelationEvent, {
            event: 'PeerRelationAdded',
            args: {
                __length__: 3,
                0: 0,
                networkId: 0,
                1: PUBKEY_HASH_1,
                pubKeyHashMine: PUBKEY_HASH_1,
                2: PUBKEY_HASH_2,
                pubKeyHashOther: PUBKEY_HASH_2
            }
        }, 'PeerRelationAdded event is emitted');

        let value = await network.getPeerInfo(PUBKEY_HASH_1);
        assert.equal(value[0], 0);
        assert.equal(value[1], PUBKEY_HASH_1);
        assert.equal(value[2], PUBKEY_HASH_2);
        addPeerRelationEvent = await network.addPeerRelation(PUBKEY_HASH_1, PUBKEY_HASH_3);
        assert.web3Event(addPeerRelationEvent, {
            event: 'PeerRelationAdded',
            args: {
                __length__: 3,
                0: 0,
                networkId: 0,
                1: PUBKEY_HASH_1,
                pubKeyHashMine: PUBKEY_HASH_1,
                2: PUBKEY_HASH_3,
                pubKeyHashOther: PUBKEY_HASH_3
            }
        }, 'PeerRelationAdded event is emitted');

        // verify first peer's relations
        value = await network.getPeerInfo(PUBKEY_HASH_1);
        assert.equal(value[0], 0);
        assert.equal(value[1], PUBKEY_HASH_1);
        assert.equal(value[2], PUBKEY_HASH_2 + "," + PUBKEY_HASH_3);
    });

    it('remove peer relation', async function () {
        await addPeersOneAndTwo();

        // add peer relations
        let addPeerRelationEvent = await network.addPeerRelation(PUBKEY_HASH_1, PUBKEY_HASH_2);
        assert.web3Event(addPeerRelationEvent, {
            event: 'PeerRelationAdded',
            args: {
                __length__: 3,
                0: 0,
                networkId: 0,
                1: PUBKEY_HASH_1,
                pubKeyHashMine: PUBKEY_HASH_1,
                2: PUBKEY_HASH_2,
                pubKeyHashOther: PUBKEY_HASH_2
            }
        }, 'PeerRelationAdded event is emitted');

        addPeerRelationEvent = await network.addPeerRelation(PUBKEY_HASH_1, PUBKEY_HASH_3);
        assert.web3Event(addPeerRelationEvent, {
            event: 'PeerRelationAdded',
            args: {
                __length__: 3,
                0: 0,
                networkId: 0,
                1: PUBKEY_HASH_1,
                pubKeyHashMine: PUBKEY_HASH_1,
                2: PUBKEY_HASH_3,
                pubKeyHashOther: PUBKEY_HASH_3
            }
        }, 'PeerRelationAdded event is emitted');

        addPeerRelationEvent = await network.addPeerRelation(PUBKEY_HASH_2, PUBKEY_HASH_3);
        assert.web3Event(addPeerRelationEvent, {
            event: 'PeerRelationAdded',
            args: {
                __length__: 3,
                0: 0,
                networkId: 0,
                1: PUBKEY_HASH_2,
                pubKeyHashMine: PUBKEY_HASH_2,
                2: PUBKEY_HASH_3,
                pubKeyHashOther: PUBKEY_HASH_3
            }
        }, 'PeerRelationAdded event is emitted');

        let peerInfo1 = await network.getPeerInfo(PUBKEY_HASH_1);
        assert.equal(peerInfo1[0], 0);
        assert.equal(peerInfo1[1], PUBKEY_HASH_1);
        assert.equal(peerInfo1[2], PUBKEY_HASH_2 + "," + PUBKEY_HASH_3);
        let peerInfo2 = await network.getPeerInfo(PUBKEY_HASH_2);
        assert.equal(peerInfo2[0], 0);
        assert.equal(peerInfo2[1], PUBKEY_HASH_2);
        assert.equal(peerInfo2[2], PUBKEY_HASH_1 + "," + PUBKEY_HASH_3);
        let peerInfo3 = await network.getPeerInfo(PUBKEY_HASH_3);
        assert.equal(peerInfo3[0], 0);
        assert.equal(peerInfo3[1], PUBKEY_HASH_3);
        assert.equal(peerInfo3[2], PUBKEY_HASH_1 + "," + PUBKEY_HASH_2);

        // remove a peer relation
        removePeerRelationEvent = await network.removePeerRelation(PUBKEY_HASH_1, PUBKEY_HASH_2);
        assert.web3Event(removePeerRelationEvent, {
            event: 'PeerRelationRemoved',
            args: {
                __length__: 3,
                0: 0,
                networkId: 0,
                1: PUBKEY_HASH_1,
                pubKeyHashMine: PUBKEY_HASH_1,
                2: PUBKEY_HASH_2,
                pubKeyHashOther: PUBKEY_HASH_2
            }
        }, 'PeerRelationRemoved event is emitted');

        peerInfo1 = await network.getPeerInfo(PUBKEY_HASH_1);
        assert.equal(peerInfo1[0], 0);
        assert.equal(peerInfo1[1], PUBKEY_HASH_1);
        assert.equal(peerInfo1[2], PUBKEY_HASH_3);
        peerInfo2 = await network.getPeerInfo(PUBKEY_HASH_2);
        assert.equal(peerInfo2[0], 0);
        assert.equal(peerInfo2[1], PUBKEY_HASH_2);
        assert.equal(peerInfo2[2], PUBKEY_HASH_3);
        peerInfo3 = await network.getPeerInfo(PUBKEY_HASH_3);
        assert.equal(peerInfo3[0], 0);
        assert.equal(peerInfo3[1], PUBKEY_HASH_3);
        assert.equal(peerInfo3[2], PUBKEY_HASH_1 + "," + PUBKEY_HASH_2);
    });

    it('turn network on/off', async function () {
        await network.updateNetworkState(false);
        assert.equal(await network.active(), false);

        // add peer should fail when network is inactive
        try {
            await network.addPeer(PUBKEY_HASH_1);
            assert.fail("add peer on an inactive network should have thrown exception");
        } catch (error) {
            assert(error.toString().includes('VM Exception'), error.toString());
        }
        assert.equal(await network.getPeerCount(), 0);

        await network.updateNetworkState(true);
        assert.equal(await network.active(), true);
    });

    it('get data JSON', async function () {
        await addPeersOneAndTwo();
        let networkManagerAddress = networkManager.address.toLowerCase()
        let jsonExpected = '{ "networkId": "0", "admin": "' + admin + '", "networkManager": "' + networkManagerAddress
            + '", "active": true, "peers": [{"pubKeyHash": "abc123", "macHash": "", "ip": "10.27.16.10/24", "neighbors": ["abc123", "456xyz"]}, {"pubKeyHash": "456xyz", "macHash": "", "ip": "10.27.16.11/24", "neighbors": ["abc123", "456xyz"]}] }';
        assert.equal(await network.getDataJSON(), jsonExpected);
    });

    // helper function for test cases which adds two new peers
    async function addPeerOne() {
        // add a peer and verify size is 1
        let addPeerEvent = await network.addPeer(PUBKEY_HASH_1);
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
        assert.equal(await network.getPeerCount(), 1);
        let networkManagerAddress = networkManager.address.toLowerCase()
        let jsonExpected = '{ "networkId": "0", "admin": "' + admin + '", "networkManager": "' + networkManagerAddress
            + '", "active": true, "peers": [{"pubKeyHash": "abc123", "macHash": "", "ip": "10.27.16.10/24", "neighbors": ["abc123]}] }';
        assert.equal(await network.getDataJSON(), jsonExpected);

        // verify peer #1
        let value = await network.getPeerInfo(PUBKEY_HASH_1);
        assert.equal(value[0], 0);
        assert.equal(value[1], PUBKEY_HASH_1);
        assert.equal(value[2], "");
        assert.equal(value[3], '10.27.16.10/24');
        assert.equal(value[4], true);
    }

    // helper function for test cases which adds two new peers
    async function addPeersOneAndTwo() {
        // add a peer and verify size is 1
        let addPeerEvent = await network.addPeer(PUBKEY_HASH_1);
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
        assert.equal(await network.getPeerCount(), 1);

        // add another peer and verify size is 2
        addPeerEvent = await network.addPeer(PUBKEY_HASH_2);
        assert.web3Event(addPeerEvent, {
            event: 'PeerAdded',
            args: {
                __length__: 2,
                0: 0,
                networkId: 0,
                1: PUBKEY_HASH_2,
                pubKeyHash: PUBKEY_HASH_2
            }
        }, 'PeerAdded event is emitted');
        assert.equal(await network.getPeerCount(), 2);
        let networkManagerAddress = networkManager.address.toLowerCase()
        let jsonExpected = '{ "networkId": "0", "admin": "' + admin + '", "networkManager": "' + networkManagerAddress
            + '", "active": true, "peers": [{"pubKeyHash": "abc123", "macHash": "", "ip": "10.27.16.10/24", "neighbors": ["abc123", "456xyz"]}, {"pubKeyHash": "456xyz", "macHash": "", "ip": "10.27.16.11/24", "neighbors": ["abc123", "456xyz"]}] }';
        assert.equal(await network.getDataJSON(), jsonExpected);

        // verify peer #1
        let value = await network.getPeerInfo(PUBKEY_HASH_1);
        assert.equal(value[0], 0);
        assert.equal(value[1], PUBKEY_HASH_1);
        assert.equal(value[2], "");
        assert.equal(value[3], '10.27.16.10/24');
        assert.equal(value[4], true);

        // verify peer #2
        value = await network.getPeerInfo(PUBKEY_HASH_2);
        assert.equal(value[0], 0);
        assert.equal(value[1], PUBKEY_HASH_2);
        assert.equal(value[2], "");
        assert.equal(value[3], '10.27.16.11/24');
        assert.equal(value[4], true);
    }

});