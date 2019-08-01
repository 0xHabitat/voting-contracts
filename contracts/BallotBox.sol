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
  uint256 constant MOTION = 123;
  bool constant IS_YES = true;
  uint256 constant CREDIT_DECIMALS = 1000000000000000000;
  
  function withdraw(
    uint256 ballotCardId,
    bytes32[] memory proof,
    uint256 removedVotes
  ) public {

    // read previous votes
    IERC1948 ballotCards = IERC1948(BALLOT_CARDS);
    bytes32 root = ballotCards.readData(ballotCardId);
    // TODO: verify proof
    // get votes at position
    int256 placedVotes = int256(proof[0]);
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
    // TODO: calculate new root
    proof[0] = bytes32(newAmount);
    ballotCards.writeData(ballotCardId, root);
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