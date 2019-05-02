pragma solidity ^0.5.0;

import "./Network.sol";
import "../utils/Util.sol";

/*
** The smart contract that handles the creation and deletion of networks, along with registering user to the global Marconi network.
** This is the top-level contract for managing all available instances of Marconi Network.
*/
contract NetworkManager {

    uint256 constant public RELEASE_VERSION = 1;                            // version of this contract
    string constant public DEFAULT_NETWORK_NAME = "Global Marconi Network"; // a name that represents the entire Marconi network (not specific to any one individual network)

    mapping (address => uint256) networkId;                       // a mapping of network to their id
    Network[] public networks;                                    // list of network contracts, each represents a Marconi network

    User[] public users;                                          // list of registered users on the global Marconi network
    mapping (string => bool) userExist;                           // a mapping of user's pubKey hash to whether they exist on the network

    /**
     * A user who has registered on the Global Marconi Network.
     */
    struct User {
        string pubKeyHash;      // the user's pubKey hash used for identifying the user
        string macHash;         // the hash of the user's MAC address
        uint256 timeOfRegister; // unix timestamp of when the user first registered
    }

    // log events
    event UserRegistered(string pubKeyHash, string macHash);
    event NetworkCreated(uint256 networkId, address networkContract, address admin);
    event NetworkDeleted(uint256 networkId, address admin);

    constructor () public {
        // init states here if needed
    }

    /**
     * Register a user to the Global Marconi Network.
     *
     * @param _pubKeyHash hash of the public key
     * @param _macHash hash of the MAC address
     */
    function registerUser(string memory _pubKeyHash, string memory _macHash) public {
        require(userExist[_pubKeyHash] == false); // check user not already registered

        // add user to list
        uint256 _id = users.length++;
        users[_id] = User({pubKeyHash: _pubKeyHash, macHash: _macHash, timeOfRegister: now});
        userExist[_pubKeyHash] = true;

        emit UserRegistered(_pubKeyHash, _macHash);
    }

    /**
     * Helper function that returns the number of existing Marconi networks.
     */
    function getUserCount() public view returns(uint) {
        return users.length;
    }

    /**
     * Create a new network of Marconi peers. The network info is encapsulated in a Network contract.
     * The admin of the network will be the address which initiated this createNetwork call.
     */
    function createNetwork() public returns (uint256 _id) {
        _id = networks.length;

        // create the network
        Network _network = new Network(_id, msg.sender, address(this));
        networks.push(_network);

        emit NetworkCreated(_id, address(_network), msg.sender);
        return _id;
    }

    /**
     * Deactivate a Marconi Network.
     *
     * @param _targetNetworkId id of the network to delete
     */
    function deleteNetwork(uint256 _targetNetworkId) public returns (bool) {
        require(networks.length > 0);                              // check there are networks available
        require(address(networks[_targetNetworkId]) != address(0x0));       // check target network exists
        require(networks[_targetNetworkId].admin() == msg.sender); // check sender is the admin

        // delete the network, this leaves a gap in the array
        // do not shift the array indices as they are also the network ids
        delete networks[_targetNetworkId];

        emit NetworkDeleted(_targetNetworkId, msg.sender);
        return true;
    }

    /**
     * Helper function that returns the number of existing Marconi networks.
     */
    function getNetworkCount() public view returns(uint _count) {
        for (uint256 i = 0; i < networks.length; i++) {
            if (address(networks[i]) != address(0x0)) {
                _count++;
            }
        }
        return _count;
    }

    /**
     * Returns hash of the user's MAC address.
     *
     * @param pubKeyHash hash of the user's public key
     */
    function getUserMacHash(string memory pubKeyHash) public view returns(string memory) {
        for (uint256 i = 0; i < users.length; i++) {
            if (Util.compareStrings(users[i].pubKeyHash, pubKeyHash)) {
                return users[i].macHash;
            }
        }
        return "";
    }

}