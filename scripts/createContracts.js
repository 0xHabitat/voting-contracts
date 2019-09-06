#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const { bufferToHex, ripemd160 } = require("ethereumjs-util");

const contracts = [
  { 
    name: 'BallotBox',
    truffleJson: require("../build/contracts/BallotBox"),
    keys: {    
      VOICE_CREDITS: "1231111111111111111111111111111111111123",
      VOICE_TOKENS: "2341111111111111111111111111111111111234",
      BALANCE_CARD: "3451111111111111111111111111111111111345",
      OPERATOR: "7891111111111111111111111111111111111789",
      TRASH_BOX: '4561111111111111111111111111111111111456',
      MOTION_ID: "deadbeef0001",
      IS_YES: "deadbeef0002"
    },
    values: {
      VOICE_CREDITS: "0x8f8FDcA55F0601187ca24507d4A1fE1b387Db90B",
      VOICE_TOKENS: "0x3442c197cc858bED2476BDd9c7d4499552780f3D",
      BALANCE_CARD: "0xCD1b3a9a7B5f84BC7829Bc7e6e23adb1960beE97",
      OPERATOR: "0x0d56caf1ccb9eddf27423a1d0f8960554e7bc9d5",
      TRASH_BOX: "0x7e897000E80787653C6A7a2D20174a4225d89753",
      MOTION_ID: "deadbeef0001",
      IS_YES: "deadbeef0002"
    }
  },
  { 
    name: 'VotingBooth',
    truffleJson: require("../build/contracts/VotingBooth"),
    keys: {
      VOICE_CREDITS: "1231111111111111111111111111111111111123",
      VOICE_TOKENS: "2341111111111111111111111111111111111234",
      BALANCE_CARD: "3451111111111111111111111111111111111345",
      YES_BOX: "4561111111111111111111111111111111111456",
      NO_BOX: "5671111111111111111111111111111111111567",
      OPERATOR: "7891111111111111111111111111111111111789",
      PROPOSAL_ID: "deadbeef0001"
    },
    values: {
      VOICE_CREDITS: "0x8f8FDcA55F0601187ca24507d4A1fE1b387Db90B",
      VOICE_TOKENS: "0x3442c197cc858bED2476BDd9c7d4499552780f3D",
      BALANCE_CARD: "0xCD1b3a9a7B5f84BC7829Bc7e6e23adb1960beE97",
      YES_BOX: "4561111111111111111111111111111111111456",
      NO_BOX: "5671111111111111111111111111111111111567",
      OPERATOR: "0x0d56caf1ccb9eddf27423a1d0f8960554e7bc9d5",
      PROPOSAL_ID: "deadbeef0001"
    }
  }
]

const outdir = process.argv[2] || "./build/spendies";

try { fs.mkdirSync(outdir); } catch (e) { }

const replaceAll = (str, find, replace) =>
  str.replace(new RegExp(find, "g"), replace.replace("0x", "").toLowerCase());


for (let contract of contracts) {
  let code = contract.truffleJson.deployedBytecode;
  
  Object.keys(contract.keys).forEach((k) => {
    console.log(k.padEnd(20, ' '), contract.keys[k], contract.values[k]);
    code = replaceAll(code, contract.keys[k], contract.values[k]);
  });
  const contractAddr = bufferToHex(ripemd160(code));

  const outFile = path.join(outdir, `${contract.name}.js`);
  fs.writeFileSync(
    outFile,
`
const { bufferToHex, ripemd160 } = require("ethereumjs-util");

const code = '${code}';

const keys = ${JSON.stringify(contract.keys, null, 2)};

const abi = ${JSON.stringify(contract.truffleJson.abi, null, 2)};

const withParams = (code) => (params) => {
  let codeCopy = code;
  Object.keys(params).forEach((k) => {
    codeCopy = replaceAll(codeCopy, keys[k], params[k]);
  });
  return { 
    address: bufferToHex(ripemd160(codeCopy)),
    code: codeCopy,
    keys,
    abi,
    withParams: withParams(codeCopy),
  };
};

const replaceAll = (str, find, replace) =>
  str.replace(new RegExp(find, "g"), replace.replace("0x", "").toLowerCase());
    
module.exports = { 
  address: '${contractAddr}',
  code,
  keys,
  abi,
  withParams: withParams(code)
};
`
  );
  console.log(`${contract.name} exported to ${outFile}\n`);
}