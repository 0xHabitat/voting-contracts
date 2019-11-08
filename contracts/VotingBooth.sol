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
  address constant LEAP_ADDR = 0x1231111111111111111111111111111111111123;
  address constant BALANCE_CARDS = 0x3451111111111111111111111111111111111345;
  uint256 constant CREDIT_DECIMALS = 1000000000000000000;

  event NewVote(
    address indexed voter,
    bytes32 indexed MOTION_ID,
    bool indexed isYes,
    uint256 placedVotes
  );
  
  function castBallot(
    uint256 balanceCardId,
    uint256 motionId,
    bytes memory proof,
    int256 placedVotes,
    int256 newVotes
  ) public {

    // read previous votes
    IERC1948 ballotCards = IERC1948(BALANCE_CARDS);
    bytes32 root = ballotCards.readData(balanceCardId);
    require(root == _getRoot(bytes32(placedVotes), motionId, proof), "proof not valid");
    if (placedVotes < 0) {
      require(newVotes < placedVotes, "can not decrease no vote");
    } else if (placedVotes > 0) {
      require(newVotes > placedVotes, "can not decrease yes vote");
    }
    require(newVotes != 0, "can not vote 0");
    uint256 diffCredits = uint256((newVotes * newVotes) - (placedVotes * placedVotes)) / CREDIT_DECIMALS;

    // transfer leap
    IERC20 leap = IERC20(LEAP_ADDR);
    address voter = ballotCards.ownerOf(balanceCardId);
    leap.transferFrom(voter, voter, diffCredits);
    
    // update ballotCard
    ballotCards.writeData(balanceCardId, _getRoot(bytes32(newVotes), motionId, proof));

    // emit event
    emit NewVote(voter, bytes32(motionId), newVotes > 0, diffCredits);
  }

}