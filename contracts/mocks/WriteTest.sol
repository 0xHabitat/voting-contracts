/**
 * Copyright (c) 2019-present, Project Democracy
 *
 * This source code is licensed under the Mozilla Public License, version 2,
 * found in the LICENSE file in the root directory of this source tree.
 */
pragma solidity ^0.5.2;
import "../IERC1948.sol";

contract WriteTest {

  address constant PASSPORTS_ADDR = 0x3451111111111111111111111111111111111345;
  
  function trade(
    uint256 passportA,
    bytes32 passDataAfter, 
    bytes memory sigA
  ) public returns (address) {
    // calculate payout for A
    IERC1948 passports = IERC1948(PASSPORTS_ADDR);
    passports.writeDataByReceipt(passportA, passDataAfter, sigA);
    return passports.ownerOf(passportA);
  }

}