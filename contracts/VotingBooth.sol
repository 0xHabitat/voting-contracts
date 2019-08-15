/**
 * Copyright (c) 2019-present, Project Democracy
 *
 * This source code is licensed under the Mozilla Public License, version 2,
 * found in the LICENSE file in the root directory of this source tree.
 */
pragma solidity ^0.5.2;
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "./SparseMerkleTree.sol";
import "./IERC1948.sol";

contract VotingBooth is SparseMerkleTree {
  address constant VOICE_CREDITS = 0x1231111111111111111111111111111111111123;
  address constant VOTES = 0x2341111111111111111111111111111111111234;
  address constant BALANCE_CARDS = 0x3451111111111111111111111111111111111345;
  address constant YES_BOX = 0x4561111111111111111111111111111111111456;
  address constant NO_BOX = 0x5671111111111111111111111111111111111567;
  uint16 constant MOTION_ID = 0x1337;
  uint256 constant CREDIT_DECIMALS = 1000000000000000000;


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
    require(root == _getRoot(bytes32(placedVotes), MOTION_ID, proof), "proof not valid");
    address destinationBallot;
    if (placedVotes < 0) {
      require(newVotes < placedVotes, "can not decrease no vote");
      destinationBallot = NO_BOX;
    } else {
      require(newVotes > placedVotes, "can not decrease yes vote");
      destinationBallot = YES_BOX;
    }
    uint256 diffCredits = uint256((newVotes * newVotes) - (placedVotes * placedVotes)) / CREDIT_DECIMALS;

    // transfer credits
    IERC20 credits = IERC20(VOICE_CREDITS);
    credits.transferFrom(ballotCards.ownerOf(balanceCardId), destinationBallot, diffCredits);
    // transfer votes
    IERC20 votes = IERC20(VOTES);
    votes.transfer(destinationBallot, abs(newVotes - placedVotes));
    
    // update ballotCard
    ballotCards.writeData(balanceCardId, _getRoot(bytes32(newVotes), MOTION_ID, proof));
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