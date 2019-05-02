pragma solidity ^0.5.0;

import "../../stringutils/strings.sol";
import "./NetworkManager.sol";
import "../utils/Util.sol";

/*
** The smart contract that represents a stand-alone Marconi Network. It handles basic interactions such as adding and
** removing of peers, as well as enabling or disabling the network.
*/
contract Network {

    using strings for *;

    uint256 constant public RELEASE_VERSION = 1;     // version of this contract
    string constant public IP_PREFIX = "10.27.16.";  // the prefix for peer's DHCP IPs
    string constant public IP_SUFFIX = "/24";        // the suffix for peer's DHCP IPs
    uint256 constant public IP_OFFSET = 10;          // start IP at 10 and move up (avoid special IP addresses)
    uint256 constant public MAX_PEER_CAPACITY = 245; // max number of peers a network can support

    uint256 public id;                         // a unique identifier for the network
    address public admin;                      // admin of the network
    address public networkManagerAddress;      // address of the NetworkManager contract

    mapping (string => uint256) peerId;        // a mapping of peer's pubkey hash to their id
    Peer[] public peers;                       // list of peers in the network
    uint256 peerCount;                         // number of active peers
    bool public active;                        // toggle on/off the network

    // log events
    event PeerAdded(uint256 networkId, string pubKeyHash);
    event PeerRemoved(uint256 networkId, string pubKeyHash);
    event PeerRelationAdded(uint256 networkId, string pubKeyHashMine, string pubKeyHashOther);
    event PeerRelationRemoved(uint256 networkId, string pubKeyHashMine, string pubKeyHashOther);

    // encapsulate a peer on the network
    struct Peer {
        uint256 networkId;   // id of the network it belongs to
        string pubKeyHash;   // pubKey hash of the peer
        string macHash;      // hash of the peer's MAC address
        string[] neighbors;  // list of pubKey hash for the peer's neighboring peers
        string ip;           // DHCP IP
        bool active;         // whether the peer is active in the network
    }

    modifier isActive {
        require(active); // check that network is active
        _;
    }

    /**
    * Set the initial state of the network.
    *
    * @param _id id of the network
    * @param _admin address of the network's admin
    */
    constructor (uint256 _id, address _admin, address _networkManagerAddress) public {
        id = _id;
        admin = _admin;
        active = true;
        networkManagerAddress = _networkManagerAddress;
    }

    /**
     * Add a peer to the target network.
     *
     * @param _pubKeyHash the hash that identifies the peer on the Marconi network
     */
    function addPeer(string memory _pubKeyHash) isActive public returns (bool) {
        require(admin == msg.sender);           // check sender is the admin
        require(peerCount < MAX_PEER_CAPACITY); // check network is not full
        require(peerId[_pubKeyHash] == 0);      // check that peer doesn't already exist

        // attempt to replace an in-active peer with the new peer
        bool replaced = false;
        uint256 _index = 0;
        for (uint256 i = 0; i < peers.length; i++) {
            if (!peers[i].active) {
                replaced = true;
                _index = i;
                break;
            }
        }
        // no in-active peer was found, so add new peer to the end
        if (!replaced) {
            _index = peers.length++;
        }

        peerId[_pubKeyHash] = _index + 1; // id starts at 1 as 0 is a default in Solidity

        Peer storage peer = peers[_index];
        peer.networkId = id;
        peer.pubKeyHash = _pubKeyHash;
        peer.active = true;

        // generate DHCP IP and assign it to the peer (e.g. 10.27.16.X/24)
        string memory _hostIP = Util.uintToStr(_index + IP_OFFSET);
        peer.ip = IP_PREFIX.toSlice().concat(_hostIP.toSlice());
        peer.ip = peer.ip.toSlice().concat(IP_SUFFIX.toSlice());

        // get peer's MAC address hash from the NetworkManager
        NetworkManager networkManager = NetworkManager(networkManagerAddress);
        peer.macHash = networkManager.getUserMacHash(_pubKeyHash);

        peerCount++;

        emit PeerAdded(id, _pubKeyHash);
        return true;
    }

    /**
     * Add a peer to another peer's neighbors.
     *
     * @param _pubKeyHashMine the hash of the peer who to add a neighboring peer to
     * @param _pubKeyHashOther the hash of the neighboring peer
     */
    function addPeerRelation(string memory _pubKeyHashMine, string memory _pubKeyHashOther) isActive public returns (bool) {
        require(admin == msg.sender); // check sender is the admin

        if (addPeerRelationOneWay(_pubKeyHashMine, _pubKeyHashOther) && addPeerRelationOneWay(_pubKeyHashOther, _pubKeyHashMine)) {
            emit PeerRelationAdded(id, _pubKeyHashMine, _pubKeyHashOther);
            return true;
        }
        return false;
    }

    /**
     * Add a peer to another peer's neighbors.
     *
     * @param _pubKeyHashMine the hash of the peer who to add a neighboring peer to
     * @param _pubKeyHashOther the hash of the neighboring peer
     */
    function addPeerRelationOneWay(string memory _pubKeyHashMine, string memory _pubKeyHashOther) isActive private returns (bool) {
        require(admin == msg.sender); // check sender is the admin

        if (peerId[_pubKeyHashMine] == 0) {
            addPeer(_pubKeyHashMine);
        }

        // get the peer and add the neighbor only if it not already exist
        uint256 _index = peerId[_pubKeyHashMine] - 1;
        bool exist = false;
        for (uint256 i = 0; i < peers[_index].neighbors.length; i++) {
            if (Util.compareStrings(peers[_index].neighbors[i], _pubKeyHashOther)) {
                exist = true;
                break;
            }
        }
        if (!exist) {
            peers[_index].neighbors.push(_pubKeyHashOther);
        }
        return true;
    }

    /**
     * Remove a peer from the target network.
     *
     * @param _pubKeyHash the hash that identifies the peer on the Marconi network
     */
    function removePeer(string memory _pubKeyHash) isActive public returns (bool) {
        require(admin == msg.sender);                   // check sender is the admin
        require(peerCount > 0);                         // check network is not empty
        require(peerId[_pubKeyHash] != 0);              // check that peer exists
        require(peers[peerId[_pubKeyHash] - 1].active); // check that peer is active

        // mark peer as in-active
        peers[peerId[_pubKeyHash] - 1].active = false;
        delete(peerId[_pubKeyHash]);

        // iterate over every peer of the network
        for (uint256 j = 0; j < peers.length; j++) {
            // iterate over the peer's neighboring peers
            for (uint256 k = 0; k < peers[j].neighbors.length; k++) {
                // delete the neighbor if found
                if (Util.compareStrings(peers[j].neighbors[k], _pubKeyHash)) {
                    // delete by swapping it with the last index, only do this if order doesn't matter
                    uint256 lastIndex = peers[j].neighbors.length - 1;
                    peers[j].neighbors[k] = peers[j].neighbors[lastIndex];
                    delete peers[j].neighbors[lastIndex];
                    peers[j].neighbors.length--;
                    break;
                }
            }
        }

        peerCount--;

        emit PeerRemoved(id, _pubKeyHash);
        return true;
    }

    /**
     * Remove the peer relations between two peers.
     *
     * @param _pubKeyHash the hash  of the peer
     * @param _pubKeyHashOther the hash of the other peer
     */
    function removePeerRelation(string memory _pubKeyHash, string memory _pubKeyHashOther) isActive public returns (bool) {
        require(admin == msg.sender);                                       // check sender is the admin
        require(peerId[_pubKeyHash] != 0 && peerId[_pubKeyHashOther] != 0); // check that peer exists

        if (removePeerRelationOneWay(_pubKeyHash, _pubKeyHashOther) && removePeerRelationOneWay(_pubKeyHashOther, _pubKeyHash)) {
            emit PeerRelationRemoved(id, _pubKeyHash, _pubKeyHashOther);
            return true;
        }
        return false;
    }

    /**
     * Helper function to remove a target neighbor from a peer.
     *
     * @param _pubKeyHash the hash of the peer
     * @param _pubKeyHashNeighbor the hash of the peer's neighbor
     */
    function removePeerRelationOneWay(string memory _pubKeyHash, string memory _pubKeyHashNeighbor) isActive private returns (bool) {
        uint256 _id = peerId[_pubKeyHash] - 1;
        // iterate over peer's neighbors
        for (uint256 j = 0; j < peers[_id].neighbors.length; j++) {
            // delete the neighbor if found
            if (Util.compareStrings(peers[_id].neighbors[j], _pubKeyHashNeighbor)) {
                // delete by swapping it with the last index, only do this if order doesn't matter
                uint256 lastIndex = peers[_id].neighbors.length - 1;
                peers[_id].neighbors[j] = peers[_id].neighbors[lastIndex];
                delete peers[_id].neighbors[lastIndex];
                peers[_id].neighbors.length--;
                return true;
            }
        }
        return false;
    }

    /**
     * Return all network info in a JSON string. This is especially useful during data migration.
     */
    function getDataJSON() public view returns (string memory ret) {
        ret = "{ ";
        ret = ret.toSlice().concat(getJSONString("networkId", Util.uintToStr(id), true).toSlice());
        ret = ret.toSlice().concat(", ".toSlice());
        ret = ret.toSlice().concat(getJSONString("admin", "0x".toSlice().concat(Util.addrToStr(admin).toSlice()), true).toSlice());
        ret = ret.toSlice().concat(", ".toSlice());
        ret = ret.toSlice().concat(getJSONString("networkManager", "0x".toSlice().concat(Util.addrToStr(networkManagerAddress).toSlice()), true).toSlice());
        ret = ret.toSlice().concat(", ".toSlice());
        ret = ret.toSlice().concat(getJSONString("active", Util.boolToStr(active), false).toSlice());

        // iterate over every peer of the network
        string memory peersJson = "[";
        for (uint256 i = 0; i < peers.length; i++) {
            Peer storage peer = peers[i];
            peersJson = peersJson.toSlice().concat("{".toSlice());
            peersJson = peersJson.toSlice().concat(getJSONString("pubKeyHash", peer.pubKeyHash, true).toSlice());
            peersJson = peersJson.toSlice().concat(", ".toSlice());
            peersJson = peersJson.toSlice().concat(getJSONString("macHash", peer.macHash, true).toSlice());
            peersJson = peersJson.toSlice().concat(", ".toSlice());
            peersJson = peersJson.toSlice().concat(getJSONString("ip", peer.ip, true).toSlice());
            peersJson = peersJson.toSlice().concat(", ".toSlice());

            // append neighbors
            string memory neighborsJson = "[";
            if (peers.length > 0) {
                neighborsJson = neighborsJson.toSlice().concat("\"".toSlice());
                neighborsJson = neighborsJson.toSlice().concat(peers[0].pubKeyHash.toSlice());
                for (uint256 j = 1; j < peers.length; j++) {
                    neighborsJson = neighborsJson.toSlice().concat("\", \"".toSlice());
                    neighborsJson = neighborsJson.toSlice().concat(peers[j].pubKeyHash.toSlice());
                    neighborsJson = neighborsJson.toSlice().concat("\"".toSlice());
                }
            }
            neighborsJson = neighborsJson.toSlice().concat("]".toSlice());

            neighborsJson = neighborsJson.toSlice().concat("}".toSlice());
            if (i < peers.length - 1) {
                neighborsJson = neighborsJson.toSlice().concat(", ".toSlice());
            }

            peersJson = peersJson.toSlice().concat(getJSONString("neighbors", neighborsJson, false).toSlice());
        }
        peersJson = peersJson.toSlice().concat("]".toSlice());

        ret = ret.toSlice().concat(", ".toSlice());
        ret = ret.toSlice().concat(getJSONString("peers", peersJson, false).toSlice());
        ret = ret.toSlice().concat(" }".toSlice());
        return ret;
    }

    /**
     * Helper function that converts a key/value pair into a JSON string.
     */
    function getJSONString(string memory key, string memory value, bool quoteValue) private pure returns (string memory ret) {
        ret = key;
        ret = ret.toSlice().concat("\": ".toSlice());
        if (quoteValue) {
            ret = ret.toSlice().concat("\"".toSlice());
        }
        ret = ret.toSlice().concat(value.toSlice());
        ret = "\"".toSlice().concat(ret.toSlice());
        if (quoteValue) {
            ret = ret.toSlice().concat("\"".toSlice());
        }
        return ret;
    }

    /**
     * Get all the neighbors of the peer having the pubKeyHash.
     *
     * @param _pubKeyHash the hash of the target peer
     */
    function getPeerRelations(string memory _pubKeyHash) public view returns (string memory ret) {
        require(peerId[_pubKeyHash] != 0); // check that peer exists

        uint256 _index = peerId[_pubKeyHash] - 1;
        // we have to use slice from the string-utils library as solidity doesn't support string concatenation
        if (peers[_index].neighbors.length > 0) {
            ret = ret.toSlice().concat(peers[_index].neighbors[0].toSlice());
            for (uint256 i = 1; i < peers[_index].neighbors.length; i++) {
                ret = ret.toSlice().concat(",".toSlice());
                ret = ret.toSlice().concat(peers[_index].neighbors[i].toSlice());
            }
        }
        return ret;
    }

    /**
     * Toggle the network on/off (Network is On by default after creation).
     *
     * @param _enable a boolean indicating the network should be on/off
     */
    function updateNetworkState(bool _enable) public {
        require(admin == msg.sender); // check sender is the admin
        require(active != _enable);   // check the current state is different than the target

        active = _enable;
    }

    /**
     * Helper function that returns a peer's information.
     */
    function getPeerInfo(string memory _pubKeyHash) public view returns(uint256, string memory, string memory, string memory, bool) {
        require(peerId[_pubKeyHash] > 0); // check that peer exists

        uint256 _index = peerId[_pubKeyHash] - 1;
        return (peers[_index].networkId, peers[_index].pubKeyHash, getPeerRelations(peers[_index].pubKeyHash), peers[_index].ip, peers[_index].active);
    }

    /**
     * Returns a string containing the pubKeyHash for all peers in the network.
     */
    function getPeers() public view returns(string memory ret) {
        ret = "";
        if (peers.length > 0) {
            ret = ret.toSlice().concat(peers[0].pubKeyHash.toSlice());
            for (uint256 i = 1; i < peers.length; i++) {
                ret = ret.toSlice().concat(",".toSlice());
                ret = ret.toSlice().concat(peers[i].pubKeyHash.toSlice());
            }
        }
        return ret;
    }

    function getPeerCount() public view returns(uint256) {
        return peerCount;
    }

    function getNetworkId() public view returns(uint256) {
        return id;
    }

    function getNetworkAdmin() public view returns(address) {
        return admin;
    }

    /**
     * Allow the admin address to be updated.
     */
    function transferNetworkAdmin(address _newAdmin) internal {
        require(admin == msg.sender);       // only the current may update the admin ownership
        require(_newAdmin != address(0x0)); // new admin address should not be 0x0
        admin = _newAdmin;
    }

}