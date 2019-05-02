pragma solidity ^0.5.0;

/*
** Interface for the manager of sub-network contracts.
*/
interface InterfaceSubnetManager {

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

    /**
     * Register a user to the Global Marconi Network.
     *
     * @param _pubKeyHash hash of the public key
     * @param _macHash hash of the MAC address
     */
    function registerUser(string calldata _pubKeyHash, string calldata _macHash) external;

    /**
     * Helper function that returns the number of existing Marconi networks.
     */
    function getUserCount() external view returns(uint);

    /**
     * Create a new network of Marconi peers. The network info is encapsulated in a Network contract.
     * The admin of the network will be the address which initiated this createNetwork call.
     */
    function createNetwork() external returns (uint256 _id);

    /**
     * Deactivate a Marconi Network.
     *
     * @param _targetNetworkId id of the network to delete
     */
    function deleteNetwork(uint256 _targetNetworkId) external returns (bool);

}