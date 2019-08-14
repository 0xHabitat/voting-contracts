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
  bytes32[DEPTH + 1] public defaultHashes;
  bytes32 public root;

  constructor() public {
    // defaultHash[0] is being set to keccak256(uint256(0));
    //defaultHashes[0] = 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563;
    for (uint8 i = 1; i <= DEPTH; i ++) {
      defaultHashes[i] = keccak256(abi.encodePacked(defaultHashes[i-1], defaultHashes[i-1]));
    }
    root = defaultHashes[DEPTH];
  }

  function read(uint16 key, bytes32 leaf, bytes memory proof) public view returns (bool) {
    bytes32 calculatedRoot = getRoot(leaf, key, proof);
    return (calculatedRoot == root);
  }

  function write(uint16 key, bytes32 prevLeaf, bytes memory proof, bytes32 newLeaf) public {
    bytes32 calculatedRoot = getRoot(prevLeaf, key, proof);
    require(calculatedRoot == root, "update proof not valid");
    root = getRoot(newLeaf, key, proof);
  }

  function del(uint16 key, bytes32 prevLeaf, bytes memory proof) public {
    bytes32 calculatedRoot = getRoot(prevLeaf, key, proof);
    require(calculatedRoot == root, "update proof not valid");
    root = getRoot(defaultHashes[0], key, proof);
  }

  // first 160 bits of the proof are the 0/1 bits
  function getRoot(bytes32 leaf, uint16 _index, bytes memory proof) public view returns (bytes32) {
    require((proof.length - 2) % 32 == 0 && proof.length <= 290, "invalid proof format"); // 290 = 32 * 9 + 2
    bytes32 proofElement;
    bytes32 computedHash = leaf;
    uint16 p = 2;  // length of trail
    uint16 proofBits;
    uint16 index = _index;
    assembly {proofBits := div(mload(add(proof, 32)), exp(256, 30))} // 30 is number of bytes to shift 

    for (uint d = 0; d < DEPTH; d++ ) {
      if (proofBits % 2 == 0) { // check if last bit of proofBits is 0
        proofElement = defaultHashes[d];
      } else {
        p += 32;
        require(proof.length >= p, "proof not long enough");
        assembly { proofElement := mload(add(proof, p)) }
      }
      if (index % 2 == 0) {
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