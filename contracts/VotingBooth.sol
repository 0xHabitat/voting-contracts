/**
 * Copyright (c) 2019-present, deora.earth
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
  uint48 constant MOTION_ID = 0xdeadbeef0001;
  uint256 constant CREDIT_DECIMALS = 1000000000000000000;

  // event NewVote(
  //   address indexed voter,
  //   uint16 indexed MOTION_ID,
  //   bool indexed isYes,
  //   uint256 placedVotes
  // );
  
  function castBallot(
    uint256 balanceCardId,
    bytes memory proof,
    int256 placedVotes,
    int256 newVotes
  ) public {

    // read previous votes
    IERC1948 ballotCards = IERC1948(BALANCE_CARDS);
    bytes32 root = ballotCards.readData(balanceCardId);
    require(root == _getRoot(bytes32(placedVotes), uint16(MOTION_ID), proof), "proof not valid");
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
    address voter = ballotCards.ownerOf(balanceCardId);
    credits.transferFrom(voter, destinationBallot, diffCredits);
    // transfer votes
    IERC20(VOTES).transfer(destinationBallot, abs(newVotes - placedVotes));
    
    // update ballotCard
    ballotCards.writeData(balanceCardId, _getRoot(bytes32(newVotes), uint16(MOTION_ID), proof));

    // emit event
    // emit NewVote(voter, uint16(MOTION_ID), newVotes > 0,diffCredits);
  }

  // account used for consolidates.
  address constant OPERATOR = 0x7891111111111111111111111111111111111789;

  // used to combine multiple contract UTXOs into one.
  function consolidate(address token, uint8 v, bytes32 r, bytes32 s) public {
    bool success;
    address signer;
    (success, signer) = safer_ecrecover(bytes32(uint256(uint160(address(this)))), v, r, s);
    require(success == true, "recover failed");
    require(signer == OPERATOR, "signer does not match");
    IERC20 erc20 = IERC20(token);
    erc20.transfer(address(this), erc20.balanceOf(address(this)));
  }
}