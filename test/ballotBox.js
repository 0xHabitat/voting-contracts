/**
 * Copyright (c) 2019-present, Project Democracy
 *
 * This source code is licensed under the Mozilla Public License, version 2,
 * found in the LICENSE file in the root directory of this source tree.
 */
const chai = require('chai');
const ethUtil = require('ethereumjs-util');
const BallotBox = artifacts.require('./BallotBox.sol');
const SimpleToken = artifacts.require('./mocks/SimpleToken');
const ERC1948 = artifacts.require('./mocks/ERC1948');
const SmtLib = require('./helpers/SmtLib.js');

const should = chai
  .use(require('chai-as-promised'))
  .should();

function replaceAll(str, find, replace) {
    return str.replace(new RegExp(find, 'g'), replace.replace('0x', ''));
}


contract('Ballot Box', (accounts) => {
  const voter = accounts[1];
  const TRASH_BOX = accounts[2];
  const balanceCardId = 123;
  const voiceBudget = '400000000000000000000';
  const totalVotes = '400000000000000000000';
  let voiceCredits;
  let votes;
  let balanceCards;
  let originalByteCode;

  beforeEach(async () => {
    voiceCredits = await SimpleToken.new(voiceBudget);
    votes = await SimpleToken.new(totalVotes);
    balanceCards = await ERC1948.new();
    originalByteCode = BallotBox._json.bytecode;
  });

  afterEach(() => {
    BallotBox._json.bytecode = originalByteCode;
  });

  it('should allow to cast ballot', async () => {

    const motionId = `0x013E`;

    // deploy vote contract
    let tmp = BallotBox._json.bytecode;
    // replace token address placeholder to real token address
    tmp = replaceAll(tmp, '1231111111111111111111111111111111111123', voiceCredits.address);
    tmp = replaceAll(tmp, '2341111111111111111111111111111111111234', votes.address);
    tmp = replaceAll(tmp, '3451111111111111111111111111111111111345', balanceCards.address);
    tmp = replaceAll(tmp, '4561111111111111111111111111111111111456', TRASH_BOX);
    tmp = replaceAll(tmp, '1337', motionId);
    BallotBox._json.bytecode = tmp;
    const ballotBox = await BallotBox.new();

    // fund ballot Box
    await voiceCredits.transfer(ballotBox.address, voiceBudget);
    await votes.transfer(ballotBox.address, totalVotes);

    // print balance card for voter
    await balanceCards.mint(voter, balanceCardId);

    let tree = new SmtLib(9, {
      '5': '0x0000000000000000000000000000000000000000000000001BC16D674EC80000',
      '318': '0x0000000000000000000000000000000000000000000000004563918244F40000'
    });
    await balanceCards.writeData(balanceCardId, tree.root, {from: voter});

    await balanceCards.approve(ballotBox.address, balanceCardId, {from: voter});

    // sending transaction
    const tx = await ballotBox.withdraw(
      balanceCardId,
      tree.createMerkleProof(318),
      '5000000000000000000',
      '5000000000000000000'
    ).should.be.fulfilled;

    // check result
    const credits = await voiceCredits.balanceOf(voter);
    assert.equal(credits.toString(10), '25000000000000000000');
    const voteAmount = await votes.balanceOf(TRASH_BOX);
    assert.equal(voteAmount.toString(10), '5000000000000000000');
    const card = await balanceCards.readData(balanceCardId);
    tree = new SmtLib(9, {
      '5': '0x0000000000000000000000000000000000000000000000001BC16D674EC80000',
      '318': '0x0000000000000000000000000000000000000000000000000000000000000000'
    });
    assert.equal(card, tree.root);
  });


});
