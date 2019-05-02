pragma solidity ^0.5.0;

import "./BaseSubnet.sol";

/*
** The smart contract that represents a stand-alone Marconi Network. It handles basic interactions such as adding and
** removing of peers, as well as enabling or disabling the network.
*/
contract MarconiSubnet is BaseSubnet {

    string constant public IP_PREFIX = "10.27.16.";  // the prefix for peer's DHCP IPs
    string constant public IP_SUFFIX = "/24";        // the suffix for peer's DHCP IPs
    uint256 constant public IP_OFFSET = 10;          // start IP at 10 and move up (avoid special IP addresses)
    uint256 constant public MAX_PEER_CAPACITY = 245; // max number of peers a network can support

    constructor (uint256 _id, address _admin) BaseSubnet(_id, _admin) public {
        // additional initialization
    }

    function getIpPrefix() internal pure returns (string memory) {
        return IP_PREFIX;
    }

    function getIpSuffix() internal pure returns (string memory) {
        return IP_SUFFIX;
    }

    function getIpOffset() internal pure returns (uint256) {
        return IP_OFFSET;
    }

    function getMaxPeerCapacity() internal pure returns (uint256) {
        return MAX_PEER_CAPACITY;
    }

}