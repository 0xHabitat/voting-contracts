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
  address constant BALLOT_CARDS = 0x3451111111111111111111111111111111111345;
  address constant YES_BOX = 0x4561111111111111111111111111111111111456;
  address constant NO_BOX = 0x5671111111111111111111111111111111111567;
  uint256 constant MOTION = 123;
  uint256 constant CREDIT_DECIMALS = 1000000000000000000;

  function abs(int256 val) internal pure returns (uint256) {
    if (val < 0) {
      return uint256(val * -1);
    } else {
      return uint256(val);
    }
  }
  
  function castBallot(
    uint256 ballotCardId,
    bytes32[] memory proof,
    int256 newVotes
  ) public {

    // read previous votes
    IERC1948 ballotCards = IERC1948(BALLOT_CARDS);
    bytes32 root = ballotCards.readData(ballotCardId);
    // TODO: verify proof
    // get votes at position
    int256 placedVotes = int256(proof[0]);
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
    credits.transferFrom(ballotCards.ownerOf(ballotCardId), destinationBallet, diffCredits);
    // transfer votes
    IERC20 votes = IERC20(VOTES);
    votes.transfer(destinationBallet, abs(newVotes - placedVotes));
    
    // update ballotCard
    // TODO: calculate new root
    ballotCards.writeData(ballotCardId, root);
  }

  // account used for consolidates.
  address constant OPERATOR = 0x5671111111111111111111111111111111111567;

  // used to combine multiple contract UTXOs into one.
  function consolidate(uint8 v, bytes32 r, bytes32 s) public {
    require(ecrecover(bytes32(bytes20(address(this))), v, r, s) == OPERATOR, "signer does not match");

    IERC20 votes = IERC20(VOTES);
    votes.transfer(address(this), votes.balanceOf(address(this)));
  }
}