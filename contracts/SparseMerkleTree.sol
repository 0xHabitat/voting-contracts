/**
 * Copyright (c) 2019-present, Project Democracy
 *
 * This source code is licensed under the Mozilla Public License, version 2,
 * found in the LICENSE file in the root directory of this source tree.
 */

pragma solidity >=0.4.21 <0.6.0;


// Based on https://rinkeby.etherscan.io/address/0x881544e0b2e02a79ad10b01eca51660889d5452b#code
contract SparseMerkleTree {

  uint8 constant DEPTH = 9;

  function _getRoot(bytes32 leaf, uint16 _index, bytes memory proof) internal view returns (bytes32) {
    require((proof.length - 2) % 32 == 0 && proof.length <= 290, "invalid proof format"); // 290 = 32 * 9 + 2
    bytes32 proofElement;
    bytes32 computedHash = leaf;
    uint16 p = 2;  // length of trail
    uint16 proofBits;
    uint16 index = _index;
    assembly {proofBits := div(mload(add(proof, 32)), exp(256, 30))} // 30 is number of bytes to shift 

    for (uint d = 0; d < DEPTH; d++ ) {
      if (proofBits % 2 == 0) { // check if last bit of proofBits is 0
        proofElement = 0;
      } else {
        p += 32;
        require(proof.length >= p, "proof not long enough");
        assembly { proofElement := mload(add(proof, p)) }
      }
      if (computedHash == 0 && proofElement == 0) {
        computedHash = 0;
      } else if (index % 2 == 0) {
        assembly {
          mstore(0, computedHash)
          mstore(0x20, proofElement)
          computedHash := keccak256(0, 0x40)
        }
      } else {
        assembly {
          mstore(0, proofElement)
          mstore(0x20, computedHash)
          computedHash := keccak256(0, 0x40)
        }
      }
      proofBits = proofBits / 2; // shift it right for next bit
      index = index / 2;
    }
    return computedHash;
  }
}