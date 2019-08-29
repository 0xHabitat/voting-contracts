/**
 * Copyright (c) 2019-present, deora.earth
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
  const voterPriv = '0x2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501201';
  const voiceBudget = '400000000000000000000';
  const totalVotes = '400000000000000000000';
  const YES = '000000000001';
  const NO = '000000000000';
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

  it('should allow to withdraw yes votes', async () => {


    let motionId = `0x000000000000`;

    let code = BallotBox._json.deployedBytecode;
    // console.log('raw box: ', code);
    const voiceCredAddr = '0x8f8FDcA55F0601187ca24507d4A1fE1b387Db90B';
    const votesAddr = '0x3442c197cc858bED2476BDd9c7d4499552780f3D';
    const balCardAddr = '0xCD1b3a9a7B5f84BC7829Bc7e6e23adb1960beE97';
    const trashAddr =   '0x0000000000000000000000000000000000000000';
    const isYes = false;
    // replace token address placeholder to real token address
    code = replaceAll(code, '1231111111111111111111111111111111111123', voiceCredAddr.replace('0x', '').toLowerCase());
    code = replaceAll(code, '2341111111111111111111111111111111111234', votesAddr.replace('0x', '').toLowerCase());
    code = replaceAll(code, '3451111111111111111111111111111111111345', balCardAddr.replace('0x', '').toLowerCase());
    code = replaceAll(code, '4561111111111111111111111111111111111456', trashAddr.replace('0x', '').toLowerCase());
    if (isYes) {
      code = replaceAll(code, 'deadbeef0002', YES);
    } else {
      code = replaceAll(code, 'deadbeef0002', NO);
    }
    
    code = replaceAll(code, 'deadbeef0001', motionId);
    // console.log('code: ', code);
    const script = Buffer.from(code.replace('0x', ''), 'hex');
    const scriptHash = ethUtil.ripemd160(script);
    console.log(`box ${isYes} contract address: 0x${scriptHash.toString('hex')}`);


    motionId = `0x00000000013E`;

    // deploy vote contract
    let tmp = BallotBox._json.bytecode;
    // replace token address placeholder to real token address
    tmp = replaceAll(tmp, '1231111111111111111111111111111111111123', voiceCredits.address);
    tmp = replaceAll(tmp, '2341111111111111111111111111111111111234', votes.address);
    tmp = replaceAll(tmp, '3451111111111111111111111111111111111345', balanceCards.address);
    tmp = replaceAll(tmp, '4561111111111111111111111111111111111456', TRASH_BOX);
    tmp = replaceAll(tmp, 'deadbeef0001', motionId);
    tmp = replaceAll(tmp, 'deadbeef0002', YES);
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
      '2500000000000000000'
    ).should.be.fulfilled;
    assert.equal(tx.logs[0].args.isYes, true, 'withdrawal on wrong box');
    assert.equal(tx.logs[0].args.voter, voter, 'wrong account');
    assert.equal(tx.logs[0].args.withdrawnVotes.toString(10), '2500000000000000000', 'wrong amount');

    // check result
    const credits = await voiceCredits.balanceOf(voter);
    assert.equal(credits.toString(10), '18750000000000000000'); // receive 18.75 back
    const voteAmount = await votes.balanceOf(TRASH_BOX);
    assert.equal(voteAmount.toString(10), '2500000000000000000');
    const card = await balanceCards.readData(balanceCardId);
    tree = new SmtLib(9, {
      '5': '0x0000000000000000000000000000000000000000000000001BC16D674EC80000',
      '318': '0x00000000000000000000000000000000000000000000000022b1c8c1227a0000'
    });
    assert.equal(card, tree.root);
  });

  it('should allow to withdraw no votes', async () => {

    motionId = `0x000000000005`;

    // deploy vote contract
    let tmp = BallotBox._json.bytecode;
    // replace token address placeholder to real token address
    tmp = replaceAll(tmp, '1231111111111111111111111111111111111123', voiceCredits.address);
    tmp = replaceAll(tmp, '2341111111111111111111111111111111111234', votes.address);
    tmp = replaceAll(tmp, '3451111111111111111111111111111111111345', balanceCards.address);
    tmp = replaceAll(tmp, '4561111111111111111111111111111111111456', TRASH_BOX);
    tmp = replaceAll(tmp, 'deadbeef0001', motionId);
    tmp = replaceAll(tmp, 'deadbeef0002', NO);
    BallotBox._json.bytecode = tmp;
    const ballotBox = await BallotBox.new();

    // fund ballot Box
    await voiceCredits.transfer(ballotBox.address, voiceBudget);
    await votes.transfer(ballotBox.address, totalVotes);

    // print balance card for voter
    await balanceCards.mint(voter, balanceCardId);

    const minusFive = '0xffffffffffffffffffffffffffffffffffffffffffffffffba9c6e7dbb0c0000';
    let tree = new SmtLib(9, {
      '5': minusFive,
      '318': '0x0000000000000000000000000000000000000000000000004563918244F40000'
    });
    await balanceCards.writeData(balanceCardId, tree.root, {from: voter});

    await balanceCards.approve(ballotBox.address, balanceCardId, {from: voter});

    // sending transaction
    const tx = await ballotBox.withdraw(
      balanceCardId,
      tree.createMerkleProof(5),
      minusFive,
      '5000000000000000000'
    ).should.be.fulfilled;

    // check result
    const credits = await voiceCredits.balanceOf(voter);
    assert.equal(credits.toString(10), '25000000000000000000');
    const voteAmount = await votes.balanceOf(TRASH_BOX);
    assert.equal(voteAmount.toString(10), '5000000000000000000');
    const card = await balanceCards.readData(balanceCardId);
    tree = new SmtLib(9, {
      '5': '0x0000000000000000000000000000000000000000000000000000000000000000',
      '318': '0x0000000000000000000000000000000000000000000000004563918244F40000'
    });
    assert.equal(card, tree.root);
  });


  it('should allow to consolidate', async () => {
    // deploy earth
    let tmp = BallotBox._json.bytecode;
    // replace token address placeholder to real token address
    tmp = replaceAll(tmp, '7891111111111111111111111111111111111789', voter.replace('0x', ''));
    BallotBox._json.bytecode = tmp;
    const boxContract = await BallotBox.new();

    await votes.transfer(boxContract.address, totalVotes);

    const buf = Buffer.alloc(32, 0);
    Buffer.from(boxContract.address.replace('0x', ''), 'hex').copy(buf, 12, 0, 20);
    const sig = ethUtil.ecsign(buf, Buffer.from(voterPriv.replace('0x', '') , 'hex'));

    // sending transaction
    const tx = await boxContract.consolidate(votes.address, sig.v, sig.r, sig.s).should.be.fulfilled;
  });

});
