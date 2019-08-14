/**
 * Copyright (c) 2019-present, Project Democracy
 *
 * This source code is licensed under the Mozilla Public License, version 2,
 * found in the LICENSE file in the root directory of this source tree.
 */
pragma solidity ^0.5.2;
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "./IERC1948.sol";

contract BallotBox {

  address constant VOICE_CREDITS = 0x1231111111111111111111111111111111111123;
  address constant VOTES = 0x2341111111111111111111111111111111111234;
  address constant BALLOT_CARDS = 0x3451111111111111111111111111111111111345;
  address constant TRASH_BOX = 0x4561111111111111111111111111111111111456;
  uint16 constant MOTION_ID = 0x1337;
  bool constant IS_YES = true;
  uint256 constant CREDIT_DECIMALS = 1000000000000000000;

  function getRoot(bytes32 leaf, uint16 _index, bytes memory proof) public view returns (bytes32) {
    require((proof.length - 2) % 32 == 0 && proof.length <= 290, "invalid proof format"); // 290 = 32 * 9 + 2
    bytes32 proofElement;
    bytes32 computedHash = leaf;
    uint16 p = 2;  // length of trail
    uint16 proofBits;
    uint16 index = _index;
    assembly {proofBits := div(mload(add(proof, 32)), exp(256, 30))} // 30 is number of bytes to shift 

    for (uint d = 0; d < 9; d++ ) {
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
  
  function withdraw(
    uint256 ballotCardId,
    bytes memory proof,
    int256 placedVotes,
    uint256 removedVotes
  ) public {

    // read previous votes
    IERC1948 ballotCards = IERC1948(BALLOT_CARDS);
    bytes32 root = ballotCards.readData(ballotCardId);
    require(root == getRoot(bytes32(placedVotes), MOTION_ID, proof), "proof not valid");

    uint256 newAmount;
    if (placedVotes < 0) {
      newAmount = uint256(placedVotes * -1);
    } else {
      newAmount = uint256(placedVotes);
    }
    require(removedVotes <= newAmount, "can not withdraw more votes than placed");
    newAmount = newAmount - removedVotes;

    // transfer credits
    IERC20 credits = IERC20(VOICE_CREDITS);
    credits.transfer(ballotCards.ownerOf(ballotCardId), (removedVotes * removedVotes) / CREDIT_DECIMALS);
    // transfer votes
    IERC20 votes = IERC20(VOTES);
    votes.transfer(TRASH_BOX, removedVotes);
    
    // update ballotCard
    ballotCards.writeData(ballotCardId, getRoot(bytes32(newAmount), MOTION_ID, proof));
  }

  // account used for consolidates.
  address constant OPERATOR = 0x7891111111111111111111111111111111111789;

  // used to combine multiple contract UTXOs into one.
  function consolidate(uint8 v, bytes32 r, bytes32 s) public {
    require(ecrecover(bytes32(bytes20(address(this))), v, r, s) == OPERATOR, "signer does not match");

    IERC20 votes = IERC20(VOTES);
    votes.transfer(address(this), votes.balanceOf(address(this)));
  }
}