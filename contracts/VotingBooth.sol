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
  // CO2 flows from Earth to Air and maybe back. This is the address of the
  // air contract.
  address constant BALLOT_CARDS = 0x4561111111111111111111111111111111111456;

  
  function cast(
    uint256 passportA,
    bytes32 passDataAfter, 
    bytes memory sigA,
    uint256 passportB,
    address countryAaddr,
    address countryBaddr
  ) public {
    // calculate payout for A
    // sender can up to a bound decide the size of the emission
    IERC1948 countryA = IERC1948(countryAaddr);
    uint256 emission = (uint256(uint32(uint256(passDataAfter))) - uint256(uint32(uint256(countryA.readData(passportA))))) * PASSPORT_FACTOR;
    require(emission <= MAX_CO2_EMISSION, "invalid emission");

    // pay out trade        
    IERC20 dai = IERC20(DAI);
    dai.transfer(countryA.ownerOf(passportA), MAX_GOE_PAYOUT * emission / MAX_CO2_EMISSION);
    IERC1948 countryB = IERC1948(countryBaddr);
    dai.transfer(countryB.ownerOf(passportB), MAX_GOE_PAYOUT * emission / MAX_CO2_EMISSION);
    
    // update passports
    countryA.writeDataByReceipt(passportA, passDataAfter, sigA);
    bytes32 dataB = countryB.readData(passportB);
    countryB.writeData(passportB, bytes32(uint256(dataB) + uint256(emission / PASSPORT_FACTOR)));

    // // emit CO2
    IERC20 co2 = IERC20(CO2);
    co2.transfer(AIR_ADDR, emission * 2);
  }

  // account used as game master.
  address constant GAME_MASTER = 0x5671111111111111111111111111111111111567;

  // used to model natural increase of CO2 if above run-away point.
  function unlockCO2(uint256 amount, uint8 v, bytes32 r, bytes32 s) public {
    require(ecrecover(bytes32(uint256(uint160(address(this))) | amount << 160), v, r, s) == GAME_MASTER, "signer does not match");
    // unlock CO2
    IERC20(CO2).transfer(AIR_ADDR, amount);
  }

  // used to combine multiple contract UTXOs into one.
  function consolidate(uint8 v, bytes32 r, bytes32 s) public {
    require(ecrecover(bytes32(bytes20(address(this))), v, r, s) == GAME_MASTER, "signer does not match");
    // lock CO2
    IERC20 co2 = IERC20(CO2);
    co2.transfer(address(this), co2.balanceOf(address(this)));
  }
}