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

contract BallotBox is SparseMerkleTree {

  address constant VOICE_CREDITS = 0x1231111111111111111111111111111111111123;
  address constant VOTES = 0x2341111111111111111111111111111111111234;
  address constant BALLOT_CARDS = 0x3451111111111111111111111111111111111345;
  address constant TRASH_BOX = 0x4561111111111111111111111111111111111456;
  uint48 constant MOTION_ID = 0xdeadbeef0001;
  uint48 constant IS_YES = 0xdeadbeef0002;
  uint256 constant CREDIT_DECIMALS = 1000000000000000000;

  event NewWithdrawal(
    address indexed voter,
    uint16 indexed MOTION_ID,
    bool indexed isYes,
    uint256 withdrawnVotes
  );
  
  function withdraw(
    uint256 ballotCardId,
    bytes memory proof,
    int256 placedVotes,
    uint256 removedVotes
  ) public {
    require(placedVotes != 0, "no withdrawal possible if no votes placed");
    require(removedVotes > 0, "can not withdraw nothing");
    // read previous votes
    IERC1948 ballotCards = IERC1948(BALLOT_CARDS);
    bytes32 root = ballotCards.readData(ballotCardId);
    require(root == _getRoot(bytes32(placedVotes), uint16(MOTION_ID), proof), "proof not valid");

    int256 newVotes;
    if (placedVotes < 0) {
      require(!getIsYes(IS_YES), "can only withdraw from no-box if bal < 0");
      require(int256(removedVotes) * -1 >= placedVotes, "can not withdraw more votes than placed");
      newVotes = placedVotes + int256(removedVotes);
    } else {
      require(getIsYes(IS_YES), "can only withdraw from yes-box if bal > 0");
      require(int256(removedVotes) <= placedVotes, "can not withdraw more votes than placed");
      newVotes = placedVotes - int256(removedVotes);
    }

    // transfer credits
    IERC20 credits = IERC20(VOICE_CREDITS);
    address voter = ballotCards.ownerOf(ballotCardId);
    uint256 remaining = uint256(abs(placedVotes)) - removedVotes;
    uint256 returned = uint256(placedVotes * placedVotes) - remaining * remaining;
    returned /= CREDIT_DECIMALS;
    credits.transfer(voter, returned);
    // transfer votes
    IERC20(VOTES).transfer(TRASH_BOX, removedVotes);
    
    // update ballotCard
    ballotCards.writeData(ballotCardId, _getRoot(bytes32(newVotes), uint16(MOTION_ID), proof));

    // emit event
    emit NewWithdrawal(voter, uint16(MOTION_ID), getIsYes(IS_YES), removedVotes);
  }

  // account used for consolidates.
  address constant OPERATOR = 0x7891111111111111111111111111111111111789;

  function getIsYes(uint48 isYes) internal pure returns (bool) {
    return (isYes > 0);
  }

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