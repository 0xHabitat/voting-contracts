/**
 * Copyright (c) 2019-present, deora.earth
 *
 * This source code is licensed under the Mozilla Public License, version 2,
 * found in the LICENSE file in the root directory of this source tree.
 */

const SmtInstance = artifacts.require("SmtInstance");
const SmtLib = require('./helpers/SmtLib.js');

contract("SmtInstance", () => {

  const leafOne = '0xa59a60d98b69a32028020fbf69c27dc2188b5756975e93b330a3f1513f383076';
  const leafTwo = '0x95d22ccdd977e992e4a530ce4f1304e1a7a1840823ea1b4f7bf3841049d197e0';
  const leafThree = '0x3d32085b3de13667b43fd7cecf200b347041918e259cbcc86796422a47fec794';
  //const leafZero = '0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563';
  const leafZero = '0x0000000000000000000000000000000000000000000000000000000000000000';

  it("should allow to verify proofs with single intersection", async() => {
    const smt = await SmtInstance.new();
    const tree = new SmtLib(9, {
        '353': leafOne,
        '9': leafTwo,
    });
    let rsp = await smt.getRoot(leafOne, 353, tree.createMerkleProof(353));
    assert.equal(rsp, tree.root);
    rsp = await smt.getRoot(leafTwo, 9, tree.createMerkleProof(9));
    assert.equal(rsp, tree.root);
    rsp = await smt.getRoot(leafZero, 2, tree.createMerkleProof('2'));
    assert.equal(rsp, tree.root);
  });

  it("should allow to update root", async() => {
    const smt = await SmtInstance.new();

    // write first leaf
    let tree = new SmtLib(9);
    await smt.write(10, leafZero, tree.createMerkleProof(10), leafOne);

    // write second leaf
    tree = new SmtLib(9, {10: leafOne});
    await smt.write(9, leafZero, tree.createMerkleProof(9), leafTwo);

    // read first leaf back
    tree = new SmtLib(9, {
      '10': leafOne,
      '9': leafTwo,
    });
    let rsp = await smt.read(10, leafOne, tree.createMerkleProof(10));
    assert(rsp);
    // negative read test
    rsp = await smt.read(10, leafTwo, tree.createMerkleProof(9));
    assert(!rsp);
    // read second leaf back
    rsp = await smt.read(9, leafTwo, tree.createMerkleProof(9));
    assert(rsp);

    // delete test
    await smt.del(10, leafOne, tree.createMerkleProof(10));

    // try to read what is left
    tree = new SmtLib(9, {
      '9': leafTwo,
    });
    rsp = await smt.read(10, leafZero, tree.createMerkleProof(10));
    assert(rsp, '10 not contained');
    rsp = await smt.read(9, leafTwo, tree.createMerkleProof(9));
    assert(rsp, '9 not contained');
  });

  it("The allow to delete element", async() => {
    const smt = await SmtInstance.new();

    // write first leaf
    let tree = new SmtLib(9);
    await smt.write(9, leafZero, tree.createMerkleProof(9), leafTwo);

    const firstRoot = await smt.root();

    tree = new SmtLib(9, {
      '9': leafTwo,
    });
    // write second leaf
    await smt.write(511, leafZero, tree.createMerkleProof(511), leafOne);

    
    tree = new SmtLib(9, {
      '9': leafTwo,
      '511': leafOne,
    });
    // read first leaf back
    let rsp = await smt.read(9, leafTwo, tree.createMerkleProof(9));
    assert(rsp);
    // read second leaf
    rsp = await smt.read(511, leafOne, tree.createMerkleProof(511));
    assert(rsp);

    // delete test
    await smt.del(511, leafOne, tree.createMerkleProof(511));

    tree = new SmtLib(9, {
      '9': leafTwo,
    });
    const afterDeleteRoot = await smt.root();
    assert.equal(firstRoot, afterDeleteRoot);
    rsp = await smt.read(9, leafTwo, tree.createMerkleProof(9));
    assert(rsp, 'reading last value fails');
  });

});