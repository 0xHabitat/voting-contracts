/**
 * Copyright (c) 2019-present, deora.earth
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

  function safer_ecrecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal returns (bool, address) {
    // We do our own memory management here. Solidity uses memory offset
    // 0x40 to store the current end of memory. We write past it (as
    // writes are memory extensions), but don't update the offset so
    // Solidity will reuse it. The memory used here is only needed for
    // this context.

    // FIXME: inline assembly can't access return values
    bool ret;
    address addr;

    assembly {
      let size := mload(0x40)
      mstore(size, hash)
      mstore(add(size, 32), v)
      mstore(add(size, 64), r)
      mstore(add(size, 96), s)

      // NOTE: we can reuse the request memory because we deal with
      //       the return code
      ret := call(3000, 1, 0, size, 128, size, 32)
      addr := mload(size)
    }

    return (ret, addr);
  }
}