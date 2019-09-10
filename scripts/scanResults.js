const fs = require('fs');
const https = require('https');
const ethers = require('ethers');
const { Tx } = require("leap-core");
const LeapProvider = require("leap-provider");
const { bufferToHex, ripemd160 } = require('ethereumjs-util');

const boothAbi = require('../build/contracts/VotingBooth').abi;
const boxAbi = require('../build/contracts/BallotBox').abi;

/** Params */
const proposalData = 'https://www.npoint.io/documents/217ecb17f01746799a3b';
const proposalsFile = 'build/proposals.json';
const votesFile = 'build/voteTxs.json';
const leapNetworkNode = 'https://testnet-node.leapdao.org';
const startBlock = 88632; // September 8, 2019, 10:39:33 UTC
const endBlock = 90780; // September 9, 2019, 16:00:41 UTC
/** ---------------- */

const factor18 = ethers.utils.bigNumberify(String(10 ** 18));

const plasma = new LeapProvider(leapNetworkNode);

const booth = new ethers.utils.Interface(boothAbi);
const voteFuncSig = booth.functions.castBallot.sighash.replace('0x', '');

const box = new ethers.utils.Interface(boxAbi);
const withdrawFuncSig = box.functions.withdraw.sighash.replace('0x', '');

const getFuncSig = tx => 
  tx.inputs[0].msgData.slice(0, 4).toString('hex');

const isSpendie = tx => tx.type === 13;

const isVote = tx => isSpendie(tx) && getFuncSig(tx) === voteFuncSig;

const isWithdraw = tx => isSpendie(tx) && getFuncSig(tx) === withdrawFuncSig;

const slimTx = ({ hash, blockHash, blockNumber, from, to, raw }) => ({
  hash, blockHash, blockNumber, from, to, raw
});

const downloadTxs = async () => {
  let txs = [];
  for (let blockNum = startBlock; blockNum <= endBlock; blockNum++) {
    txs = txs.concat(
      (await plasma.getBlock(blockNum, true)).transactions.map(slimTx)
    );
    process.stdout.write(`\rDownloading block: ${blockNum}`);
  }
  console.log();
  fs.writeFileSync(`./${votesFile}`, JSON.stringify(txs, null, 2));
  return txs;
};

const getTxData = () => {
  if (fs.existsSync(`./${votesFile}`)) {
    return require(`../${votesFile}`);
  }
  return downloadTxs();
};

const slimProposal = ({ 
  title, proposalId, boothAddress, yesBoxAddress, noBoxAddress
}) => ({
  title, proposalId, boothAddress, yesBoxAddress, noBoxAddress
});

const downloadProposals = async () => {
  return new Promise((resolve, reject) => 
    https.get(proposalData, (res) => {
      let raw = '';
      res.on('data', d => raw += d);
      res.on('end', () => resolve(JSON.parse(raw)));
      res.on('error', e => reject(e));
    })
  );  
};

const getProposals = async () => {
  if (fs.existsSync(`./${proposalsFile}`)) {
    return require(`../${proposalsFile}`);
  }
  
  const rawProps = await downloadProposals();
  const proposals = rawProps.contents.proposals
    .filter(p => p.proposalId)
    .map(slimProposal);

  fs.writeFileSync(`./${proposalsFile}`, JSON.stringify(proposals, null, 2));
  return proposals;
};

const getVotes = (tx) => {
  // vote is a 4th argument (index 3) to castBallot/withdraw call
  const votes = ethers.utils.defaultAbiCoder.decode(
    booth.functions.castBallot.inputs.map(i => i.type),
    bufferToHex(tx.inputs[0].msgData.slice(4)) // cut a func sig
  )[3].div(factor18).toNumber();

  return isWithdraw(tx) ? -votes : votes;
};

const getProposalByBox = (proposals, boxAddress) =>
  proposals.find((prop) => 
      prop.yesBoxAddress === boxAddress 
      || prop.noBoxAddress === boxAddress
  );

const countByNumberOfVotes = (arr) => 
  arr.reduce((r, v) => {
    r[v[1]] = (r[v[1]] || 0) + 1;
    return r;
  }, {});

const getBoxAddress = (tx, voter) => {
  if (isWithdraw(tx)) {
    return bufferToHex(ripemd160(tx.inputs[0].script));
  }
  return tx.outputs.find(o => o.address !== voter && o.color === 4).address;
};

const getProposalId = (tx, proposals, voter) => {
  const boxAddr = getBoxAddress(tx, voter);
  const { proposalId } = getProposalByBox(proposals, boxAddr) || {};
  if (proposalId) {
    return proposalId;
  }
  console.warn(
    'Unknown proposal vote',
    JSON.stringify({ boxAddr })
  );
};

(async () => {
  const txs = await getTxData();
  const proposals = await getProposals();
  const distr = {};
  const voters = new Set();
  const votes = txs.map(t => {
    const tx = Tx.fromRaw(t.raw);
    const withdrawalTx = isWithdraw(tx);
    if (isVote(tx) || withdrawalTx) {
      const voter = tx.inputs[1].signer; // balance card signer
      voters.add(voter);
      const proposalId = getProposalId(tx, proposals, voter);
      if (!proposalId) {
        return;
      }
      
      const proposalVotes = distr[proposalId] = distr[proposalId] || {};

      let votes = getVotes(tx);
      const prevVote = (proposalVotes[voter] || 0);
      
      // invert withdrawal value for No Box, so it negates nicely when summed up
      if (prevVote < 0 && withdrawalTx) {
        votes = -votes;
      }
      
      // aggregate votes by the voter for the proposal
      proposalVotes[voter] = (proposalVotes[voter] || 0) + votes;

      return { 
        proposalId, 
        voter,
        votes,
        type: withdrawalTx ? 'w' : 'v'
      };
    }
    return;
  });

  // prepend votes array with vote 0 for each active voter for each proposal
  // so once summed up we see 0 votes
  const votersArr = new Array(...voters);
  let votesWithDefault = [];
  proposals.forEach(p => {
    votesWithDefault = votesWithDefault.concat(
      votersArr.map(v => ({
        proposalId: p.proposalId,
        voter: v,
        votes: 0,
        type: 'v'
      }))
    );
  });
  votesWithDefault = votesWithDefault.concat(votes);  
  
  fs.writeFileSync(`./build/rawVotes.csv`, votesWithDefault.filter(v => !!v).map(v => 
    `${v.proposalId},${v.voter},${v.type},${v.votes}`  
  ).join('\n'));

  // distr is a Map<proposalId: string, Map<voter: address, vote: number>>
  // groupedDistr is a [{ proposalId:string, distr: Map<vote: number, count: number>}]
  // where `count` is a number of users who put`vote` number of votes for `proposalId`
  const groupedDistr = Object.keys(distrs)
    .sort()
    .map((proposalId) => 
    ({ proposalId, distr: countByNumberOfVotes(Object.entries(distr[proposalId])) })
  );

  // squash `groupedDistr` with proposal id and dump to CSV
  const distributionByVoteCSV = [`Proposal,Votes,Count`].concat(...groupedDistr.map((v) =>
      Object.entries(v.distr)
        .sort((a, b) => a[0] - b[0])
        .map(([votes, count]) => `${v.proposalId},${votes},${count}`)
  ));
  
  fs.writeFileSync(`./build/distributionByVote.csv`, distributionByVoteCSV.join('\n'))
  console.log('Distribution by vote saved to:', './build/distributionByVote.csv');  

  fs.writeFileSync(`./build/distr.json`, JSON.stringify(distr, null, 2));

  const flatDistr = [].concat(...Object.entries(distr).map(([proposalId, votes]) =>
    Object.entries(votes).map((v) => [proposalId, ...v])
  ));

  fs.writeFileSync(`./build/distr.csv`, flatDistr.map(v => 
    `${v[0]},${v[1]},${v[2]}`  
  ).join('\n'));

  console.log("total txs: ", txs.length);
  console.log('voters:', voters.size);
  return;  
})();

