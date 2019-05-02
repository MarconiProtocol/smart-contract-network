pragma solidity ^0.5.0;

/*
 ** Utility functions used by Network and NetworkManager.
 */
library Util {

    /*
     * Compare if two strings are equal.
     */
    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    /*
     * Convert address into a human-readable ASCII string.
     */
    function addrToStr(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            byte b = byte(uint8(uint(x) / (2**(8*(19 - i)))));
            byte hi = byte(uint8(b) / 16);
            byte lo = byte(uint8(b) - 16 * uint8(hi));
            s[2*i] = char(hi);
            s[2*i+1] = char(lo);
        }
        return string(s);
    }

    /*
     * Convert byte to char.
     */
    function char(byte b) private pure returns (byte c) {
        if (uint8(b) < 10) return byte(uint8(b) + 0x30);
        else return byte(uint8(b) + 0x57);
    }

    /**
     * Converts uint to string. Referenced from: https://github.com/oraclize/ethereum-api/blob/master/oraclizeAPI_0.5.sol
     */
    function uintToStr(uint i) internal pure returns (string memory) {
        if (i == 0) {
            return "0";
        }
        uint j = i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (i != 0) {
            bstr[k--] = byte(uint8(48 + i % 10));
            i /= 10;
        }
        return string(bstr);
    }

    /**
     * Converts boolean to string.
     */
    function boolToStr(bool b) internal pure returns (string memory) {
        if (b) {
            return "true";
        }
        return "false";
    }

}