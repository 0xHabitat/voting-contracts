/**
 * Copyright (c) 2019-present, Project Democracy
 *
 * This source code is licensed under the Mozilla Public License, version 2,
 * found in the LICENSE file in the root directory of this source tree.
 */
const chai = require('chai');
const ethUtil = require('ethereumjs-util');
const VotingBooth = artifacts.require('./VotingBooth.sol');
const SimpleToken = artifacts.require('./mocks/SimpleToken');
const ERC1948 = artifacts.require('./mocks/ERC1948');

const should = chai
  .use(require('chai-as-promised'))
  .should();

function replaceAll(str, find, replace) {
    return str.replace(new RegExp(find, 'g'), replace.replace('0x', ''));
}


contract('Voting Booth', (accounts) => {
  const voter = accounts[1];
  const yesBox = accounts[2];
  const noBox = accounts[3];
  const voterPriv = '0x2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501201';
  const dataBefore = '0x0000000000000000000000000000000000000000000000000000000000000000';
  const ballotCardId = 123;
  const voiceBudget = '400000000000000000000';
  const totalVotes = '400000000000000000000';
  let voiceCredits;
  let votes;
  let ballotCards;
  let originalByteCode;

  beforeEach(async () => {
    voiceCredits = await SimpleToken.new(voiceBudget);
    votes = await SimpleToken.new(totalVotes);
    ballotCards = await ERC1948.new();
    originalByteCode = VotingBooth._json.bytecode;
  });

  afterEach(() => {
    VotingBooth._json.bytecode = originalByteCode;
  });

  it('should allow to cast ballot', async () => {

    // deploy vote contract
    let tmp = VotingBooth._json.bytecode;
    // replace token address placeholder to real token address
    tmp = replaceAll(tmp, '1231111111111111111111111111111111111123', voiceCredits.address);
    tmp = replaceAll(tmp, '2341111111111111111111111111111111111234', votes.address);
    tmp = replaceAll(tmp, '3451111111111111111111111111111111111345', ballotCards.address);
    tmp = replaceAll(tmp, '4561111111111111111111111111111111111456', yesBox);
    tmp = replaceAll(tmp, '5671111111111111111111111111111111111567', noBox);
    VotingBooth._json.bytecode = tmp;
    const voteContract = await VotingBooth.new();

    // only needed for testnet deployment
    // let code = VotingBooth._json.deployedBytecode;
    // code = replaceAll(code, '1231111111111111111111111111111111111123', 'F64fFBC4A69631D327590f4151B79816a193a8c6'.toLowerCase());
    // code = replaceAll(code, '2341111111111111111111111111111111111234', '1f89Fb2199220a350287B162B9D0A330A2D2eFAD'.toLowerCase());
    // code = replaceAll(code, '4561111111111111111111111111111111111456', '8db6B632D743aef641146DC943acb64957155388');
    // console.log('code: ', code);
    // const script = Buffer.from(code.replace('0x', ''), 'hex');
    // const scriptHash = ethUtil.ripemd160(script);
    // console.log(`vote contract address: 0x${scriptHash.toString('hex')}`);

    // fund voter
    await voiceCredits.transfer(voter, voiceBudget);
    await votes.transfer(voteContract.address, totalVotes);

    // print ballot card for voter
    await ballotCards.mint(voter, ballotCardId);
    await ballotCards.approve(voteContract.address, ballotCardId, {from: voter});

    // voter signing transaction
    await voiceCredits.approve(voteContract.address, voiceBudget, {from: voter});

    // sending transaction
    const tx = await voteContract.castBallot(
      ballotCardId,
      [dataBefore],
      '3000000000000000000',
    ).should.be.fulfilled;

  });


});
