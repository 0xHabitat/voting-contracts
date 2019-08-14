/**
 * Copyright (c) 2019-present, Project Democracy
 *
 * This source code is licensed under the Mozilla Public License, version 2,
 * found in the LICENSE file in the root directory of this source tree.
 */
pragma solidity ^0.5.2;
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "./IERC1948.sol";

contract VotingBooth {
  address constant VOICE_CREDITS = 0x1231111111111111111111111111111111111123;
  address constant VOTES = 0x2341111111111111111111111111111111111234;
  address constant BALANCE_CARDS = 0x3451111111111111111111111111111111111345;
  address constant YES_BOX = 0x4561111111111111111111111111111111111456;
  address constant NO_BOX = 0x5671111111111111111111111111111111111567;
  uint16 constant MOTION_ID = 0x1337;
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

  function abs(int256 val) internal pure returns (uint256) {
    if (val < 0) {
      return uint256(val * -1);
    } else {
      return uint256(val);
    }
  }
  
  function castBallot(
    uint256 balanceCardId,
    bytes memory proof,
    int256 placedVotes,
    int256 newVotes
  ) public {

    // read previous votes
    IERC1948 ballotCards = IERC1948(BALANCE_CARDS);
    bytes32 root = ballotCards.readData(balanceCardId);
    require(root == getRoot(bytes32(placedVotes), MOTION_ID, proof), "proof not valid");
    address destinationBallet;
    if (placedVotes < 0) {
      require(newVotes < placedVotes, "can not decrease no vote");
      destinationBallet = NO_BOX;
    } else {
      require(newVotes > placedVotes, "can not decrease yes vote");
      destinationBallet = YES_BOX;
    }
    uint256 diffCredits = uint256((newVotes * newVotes) - (placedVotes * placedVotes)) / CREDIT_DECIMALS;

    // transfer credits
    IERC20 credits = IERC20(VOICE_CREDITS);
    credits.transferFrom(ballotCards.ownerOf(balanceCardId), destinationBallet, diffCredits);
    // transfer votes
    IERC20 votes = IERC20(VOTES);
    votes.transfer(destinationBallet, abs(newVotes - placedVotes));
    
    // update ballotCard
    ballotCards.writeData(balanceCardId, getRoot(bytes32(newVotes), MOTION_ID, proof));
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