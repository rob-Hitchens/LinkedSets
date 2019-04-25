pragma solidity 0.5.1;

contract ConvertUtils {
    
    function addressToBytes32(address a) public pure returns(bytes32) {
        return bytes32(uint(uint160(a)));
    }
    
    function bytes32ToAddress(bytes32 b) public pure returns(address) {
        return address(uint160(uint(b)));
    }
    
}
