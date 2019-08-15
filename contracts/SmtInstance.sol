/**
 * Copyright (c) 2019-present, Project Democracy
 *
 * This source code is licensed under the Mozilla Public License, version 2,
 * found in the LICENSE file in the root directory of this source tree.
 */

pragma solidity >=0.4.21 <0.6.0;
import "./SparseMerkleTree.sol";


// Based on https://rinkeby.etherscan.io/address/0x881544e0b2e02a79ad10b01eca51660889d5452b#code
contract SmtInstance is SparseMerkleTree {

  bytes32 public root;

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
    root = getRoot(0, key, proof);
  }

  function getRoot(bytes32 leaf, uint16 _index, bytes memory proof) public view returns (bytes32) {
    return _getRoot(leaf, _index, proof);
  }
}