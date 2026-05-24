---
name: zero-knowledge-proofs
description: Implement zero-knowledge proofs for privacy-preserving authentication, credential verification, and computation. Covers ZK-SNARKs with circom/snarkjs, Groth16 and PLONK proof systems, Merkle tree membership proofs, and ZK applications in Node.js and Rust.
version: 1.0.0
tags: [zero-knowledge, zkp, zk-snarks, circom, snarkjs, cryptography, privacy, groth16, plonk, merkle]
---

# Zero-Knowledge Proofs

## Overview

Zero-knowledge proofs allow one party (the prover) to convince another party (the verifier) that a statement is true without revealing any information beyond the truth of the statement itself. Modern ZK-SNARKs (Succinct Non-interactive Arguments of Knowledge) enable off-chain computation with on-chain verification — a prover computes a proof in milliseconds that the verifier checks in microseconds. The circom/snarkjs toolchain compiles arithmetic circuits to R1CS constraint systems and generates Groth16 or PLONK proofs.

## When to Use

- Proving credential ownership (age, membership) without revealing the credential itself
- Private voting systems where votes are verifiable without being linkable to voters
- Blockchain rollups — proving correct execution of thousands of transactions off-chain
- Password authentication where the server never learns the password
- Proving Merkle tree membership (allowlists, NFT ownership) without revealing siblings
- Range proofs (proving a value is in [0, 100] without revealing it)
- Identity verification with regulatory compliance but no data sharing

## Step-by-Step Workflow

### 1. Writing Circuits with circom

```bash
# Install circom and snarkjs
npm install -g snarkjs
curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh
cargo install circom

# Or: npm install circom2 snarkjs
```

```circom
// circuits/range_proof.circom
// Prove that a secret value is in range [0, 2^n) without revealing it
pragma circom 2.1.4;

include "node_modules/circomlib/circuits/bitify.circom";
include "node_modules/circomlib/circuits/comparators.circom";

// Proves: lower <= value <= upper (where lower and upper are PUBLIC)
template RangeProof(BITS) {
    signal input value;   // PRIVATE: the secret value
    signal input lower;   // PUBLIC: lower bound
    signal input upper;   // PUBLIC: upper bound

    component n2b = Num2Bits(BITS);
    n2b.in <== value;  // Proves value fits in BITS bits (non-negative, < 2^BITS)

    component gte = GreaterEqThan(BITS);
    gte.in[0] <== value;
    gte.in[1] <== lower;
    gte.out === 1;  // Constraint: value >= lower

    component lte = LessEqThan(BITS);
    lte.in[0] <== value;
    lte.in[1] <== upper;
    lte.out === 1;  // Constraint: value <= upper
}

component main {public [lower, upper]} = RangeProof(32);
```

```circom
// circuits/merkle_membership.circom
// Prove membership in a Merkle tree without revealing the leaf or path
pragma circom 2.1.4;

include "node_modules/circomlib/circuits/poseidon.circom";
include "node_modules/circomlib/circuits/mux1.circom";

template MerkleProof(LEVELS) {
    signal input leaf;              // PRIVATE: the leaf value
    signal input pathElements[LEVELS];  // PRIVATE: sibling hashes
    signal input pathIndices[LEVELS];   // PRIVATE: 0=left, 1=right at each level
    signal input root;              // PUBLIC: the known Merkle root

    component hashers[LEVELS];
    component muxLeft[LEVELS];
    component muxRight[LEVELS];

    signal levelHashes[LEVELS + 1];
    levelHashes[0] <== leaf;

    for (var i = 0; i < LEVELS; i++) {
        hashers[i] = Poseidon(2);
        muxLeft[i] = Mux1();
        muxRight[i] = Mux1();

        // If pathIndices[i] == 0: current is left, sibling is right
        // If pathIndices[i] == 1: current is right, sibling is left
        muxLeft[i].c[0] <== levelHashes[i];
        muxLeft[i].c[1] <== pathElements[i];
        muxLeft[i].s <== pathIndices[i];

        muxRight[i].c[0] <== pathElements[i];
        muxRight[i].c[1] <== levelHashes[i];
        muxRight[i].s <== pathIndices[i];

        hashers[i].inputs[0] <== muxLeft[i].out;
        hashers[i].inputs[1] <== muxRight[i].out;
        levelHashes[i + 1] <== hashers[i].out;
    }

    root === levelHashes[LEVELS];  // Final hash must equal known root
}

component main {public [root]} = MerkleProof(20);
```

### 2. Compiling Circuits and Trusted Setup

```bash
# Compile the circuit to R1CS and witness generator
circom circuits/range_proof.circom --r1cs --wasm --sym -o build/

# Phase 1: Powers of Tau ceremony (reusable for all circuits up to 2^20 constraints)
snarkjs powersoftau new bn128 20 build/pot20_0000.ptau -v
snarkjs powersoftau contribute build/pot20_0000.ptau build/pot20_0001.ptau \
    --name="First Contributor" -v

# In production: use an existing powers of tau file from Hermez/Iden3
# wget https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_20.ptau

snarkjs powersoftau prepare phase2 build/pot20_0001.ptau build/pot20_final.ptau -v

# Phase 2: Circuit-specific setup (Groth16)
snarkjs groth16 setup build/range_proof.r1cs build/pot20_final.ptau build/range_proof_0000.zkey
snarkjs zkey contribute build/range_proof_0000.zkey build/range_proof_final.zkey \
    --name="Circuit Contributor" -v
snarkjs zkey export verificationkey build/range_proof_final.zkey build/verification_key.json

# PLONK setup (universal — no circuit-specific ceremony needed)
snarkjs plonk setup build/range_proof.r1cs build/pot20_final.ptau build/range_proof_plonk.zkey
```

### 3. Generating and Verifying Proofs in Node.js

```javascript
// src/zkp/range-proof.js
const snarkjs = require("snarkjs");
const { buildPoseidon } = require("circomlibjs");
const path = require("path");

const WASM_PATH = path.join(__dirname, "../../build/range_proof_js/range_proof.wasm");
const ZKEY_PATH = path.join(__dirname, "../../build/range_proof_final.zkey");
const VKEY_PATH = path.join(__dirname, "../../build/verification_key.json");

/**
 * Generate a ZK proof that secretValue is in [lower, upper]
 * The proof reveals that the range check passed but NOT the secret value.
 */
async function proveInRange(secretValue, lower, upper) {
  const input = {
    value: secretValue.toString(),   // Private input
    lower: lower.toString(),         // Public input
    upper: upper.toString(),         // Public input
  };

  const { proof, publicSignals } = await snarkjs.groth16.fullProve(
    input,
    WASM_PATH,
    ZKEY_PATH
  );

  // publicSignals = [lower, upper] — the public inputs visible to verifier
  // proof contains (pi_a, pi_b, pi_c) — the elliptic curve points
  return { proof, publicSignals };
}

/**
 * Verify a range proof — called by the verifier (no secret needed)
 */
async function verifyRangeProof(proof, publicSignals) {
  const vKey = require(VKEY_PATH);
  const isValid = await snarkjs.groth16.verify(vKey, publicSignals, proof);
  return isValid;
}

// Usage example
async function main() {
  const secretAge = 25;
  const minAge = 18;
  const maxAge = 99;

  console.log("Generating proof that age is in [18, 99]...");
  const { proof, publicSignals } = await proveInRange(secretAge, minAge, maxAge);
  console.log("Proof generated:", JSON.stringify(proof, null, 2).slice(0, 100) + "...");

  const valid = await verifyRangeProof(proof, publicSignals);
  console.log("Proof valid:", valid);  // true — without knowing secretAge is 25

  // Wrong inputs — should fail
  const { proof: fakeProof, publicSignals: fakeSignals } = await proveInRange(
    secretAge, 21, 99  // Different range — different public signals
  );
  const invalidAttempt = await verifyRangeProof(fakeProof, publicSignals);
  console.log("Tampered proof valid:", invalidAttempt);  // false
}

module.exports = { proveInRange, verifyRangeProof };
```

### 4. Merkle Tree with ZK Membership Proof

```javascript
// src/zkp/merkle-zk.js
const { buildPoseidon } = require("circomlibjs");
const snarkjs = require("snarkjs");

class ZKMerkleTree {
  constructor(depth = 20) {
    this.depth = depth;
    this.leaves = new Map();
    this.zeros = [];
    this.poseidon = null;
  }

  async init() {
    this.poseidon = await buildPoseidon();
    // Precompute zero values for each level
    this.zeros[0] = BigInt(0);
    for (let i = 1; i <= this.depth; i++) {
      this.zeros[i] = this.hash(this.zeros[i - 1], this.zeros[i - 1]);
    }
  }

  hash(left, right) {
    const result = this.poseidon([left, right]);
    return this.poseidon.F.toObject(result);
  }

  insert(index, leaf) {
    this.leaves.set(index, BigInt(leaf));
  }

  getNode(level, index) {
    if (level === 0) {
      return this.leaves.get(index) ?? this.zeros[0];
    }
    const left = this.getNode(level - 1, 2 * index);
    const right = this.getNode(level - 1, 2 * index + 1);
    return this.hash(left, right);
  }

  get root() {
    return this.getNode(this.depth, 0);
  }

  /**
   * Generate Merkle path for proving membership at leafIndex
   * Returns { pathElements, pathIndices } for the circom circuit
   */
  getMembershipProofInputs(leafIndex) {
    const pathElements = [];
    const pathIndices = [];
    let currentIndex = leafIndex;

    for (let level = 0; level < this.depth; level++) {
      const siblingIndex = currentIndex % 2 === 0
        ? currentIndex + 1
        : currentIndex - 1;
      const isRightNode = currentIndex % 2 === 1;

      pathElements.push(this.getNode(level, siblingIndex));
      pathIndices.push(isRightNode ? 1 : 0);
      currentIndex = Math.floor(currentIndex / 2);
    }

    return { pathElements, pathIndices };
  }

  async generateMembershipProof(leafIndex, secretLeafValue) {
    const { pathElements, pathIndices } = this.getMembershipProofInputs(leafIndex);

    const input = {
      leaf: secretLeafValue.toString(),
      pathElements: pathElements.map(e => e.toString()),
      pathIndices: pathIndices.map(i => i.toString()),
      root: this.root.toString(),
    };

    const { proof, publicSignals } = await snarkjs.groth16.fullProve(
      input,
      "build/merkle_membership_js/merkle_membership.wasm",
      "build/merkle_membership_final.zkey"
    );

    return { proof, publicSignals };  // publicSignals = [root]
  }
}

// Usage: prove NFT allowlist membership
async function allowlistExample() {
  const tree = new ZKMerkleTree(20);
  await tree.init();

  // Build allowlist tree
  const allowedUsers = [
    { address: "0xAlice...", secret: BigInt("0x1234...") },
    { address: "0xBob...",   secret: BigInt("0x5678...") },
  ];

  allowedUsers.forEach((user, i) => tree.insert(i, user.secret));
  const merkleRoot = tree.root;
  console.log("Merkle root:", merkleRoot.toString());

  // Alice proves membership without revealing which index she's at
  const { proof, publicSignals } = await tree.generateMembershipProof(
    0,
    allowedUsers[0].secret
  );

  return { proof, publicSignals, merkleRoot };
}
```

## Key Commands Reference

```bash
# Compile circuit
circom circuit.circom --r1cs --wasm --sym --output build/

# Show R1CS stats (constraint count)
snarkjs r1cs info build/circuit.r1cs
snarkjs r1cs print build/circuit.r1cs build/circuit.sym

# Generate witness from inputs
node build/circuit_js/generate_witness.js \
    build/circuit_js/circuit.wasm \
    input.json \
    build/witness.wtns

# Compute witness manually
snarkjs wtns calculate build/circuit_js/circuit.wasm input.json build/witness.wtns

# Groth16 — generate proof
snarkjs groth16 prove build/circuit_final.zkey build/witness.wtns \
    build/proof.json build/public.json

# Groth16 — verify proof
snarkjs groth16 verify build/verification_key.json build/public.json build/proof.json

# PLONK — generate and verify
snarkjs plonk prove build/circuit_plonk.zkey build/witness.wtns build/proof.json build/public.json
snarkjs plonk verify build/verification_key.json build/public.json build/proof.json

# Export Solidity verifier contract
snarkjs zkey export solidityverifier build/circuit_final.zkey contracts/Verifier.sol
snarkjs zkey export soliditycalldata build/public.json build/proof.json

# Test circuit with specific inputs
snarkjs wtns check build/witness.wtns build/circuit.r1cs
```

## Common Patterns

### Pattern 1: Age Verification Without Revealing Age

```javascript
// Prove: user is 18+ without revealing exact birthdate
// Circuit: prove hash(secret_birthdate) == known_commitment AND birthdate <= today - 18years

// circom snippet: age_verify.circom
/*
template AgeVerify() {
    signal input secretBirthdate;     // PRIVATE: Unix timestamp
    signal input commitment;          // PUBLIC: Poseidon hash stored at registration
    signal input currentDate;         // PUBLIC: current date (Unix timestamp)
    signal input minAge;              // PUBLIC: 18 years in seconds

    component hasher = Poseidon(1);
    hasher.inputs[0] <== secretBirthdate;
    hasher.out === commitment;        // Proves they know the preimage

    signal age;
    age <== currentDate - secretBirthdate;

    component gte = GreaterEqThan(32);
    gte.in[0] <== age;
    gte.in[1] <== minAge;
    gte.out === 1;
}
*/

async function registerUser(secretBirthdate) {
  const poseidon = await buildPoseidon();
  const commitment = poseidon.F.toObject(poseidon([secretBirthdate]));
  // Store commitment on server — no birthdate stored
  return commitment;
}

async function proveAdult(secretBirthdate, commitment) {
  const currentDate = Math.floor(Date.now() / 1000);
  const minAge = 18 * 365.25 * 24 * 3600;  // 18 years in seconds

  return snarkjs.groth16.fullProve(
    { secretBirthdate: secretBirthdate.toString(), commitment: commitment.toString(),
      currentDate: Math.floor(currentDate).toString(), minAge: Math.floor(minAge).toString() },
    "build/age_verify_js/age_verify.wasm",
    "build/age_verify_final.zkey"
  );
}
```

### Pattern 2: Recursive ZK Proofs (Proof Aggregation)

```javascript
// Aggregate multiple Groth16 proofs into one using SnarkPack or Nova folding
// Useful for blockchain batch verification

// Using snarkjs recursive approach — verify a proof inside a circuit
// This pattern is used by zkEVM rollups to batch thousands of tx proofs

/*
// recursive_verifier.circom
template RecursiveVerify() {
    // Inputs from inner proof
    signal input proofA[2];
    signal input proofB[2][2];
    signal input proofC[2];
    signal input publicSignals[N];

    component verifier = Groth16Verifier();  // Generated from snarkjs
    verifier.proofA <== proofA;
    verifier.proofB <== proofB;
    verifier.proofC <== proofC;
    verifier.publicInputs <== publicSignals;
    verifier.isValid === 1;
}
*/

// Practical: batch verify multiple proofs on EVM
async function exportSolidityCalldata(proofs) {
  const calldataList = await Promise.all(
    proofs.map(({ proof, publicSignals }) =>
      snarkjs.groth16.exportSolidityCallData(proof, publicSignals)
    )
  );
  return calldataList;
}
```

### Pattern 3: Nullifiers for Double-Spend Prevention

```javascript
// Pattern: Spend a ZK coin exactly once using nullifiers
// nullifier = hash(secret, nullifierKey) — revealed on spend, prevents re-spend

/*
// spend.circom
template Spend() {
    signal input secret;         // PRIVATE: unique secret
    signal input nullifierKey;   // PRIVATE: user's key
    signal input commitment;     // PUBLIC: hash(secret) stored in tree
    signal input nullifier;      // PUBLIC: hash(secret, nullifierKey) — logged on chain
    signal input root;           // PUBLIC: current Merkle root

    // Prove commitment exists in tree
    component membership = MerkleProof(20);
    // ... membership check ...

    // Prove nullifier = hash(secret, nullifierKey) without revealing secret or key
    component nullifierHasher = Poseidon(2);
    nullifierHasher.inputs[0] <== secret;
    nullifierHasher.inputs[1] <== nullifierKey;
    nullifierHasher.out === nullifier;
}
*/

class NullifierRegistry {
  constructor() {
    this.spentNullifiers = new Set();
  }

  async spend(proof, publicSignals) {
    const [root, nullifier] = publicSignals;
    if (this.spentNullifiers.has(nullifier)) {
      throw new Error("Double spend detected: nullifier already used");
    }
    const valid = await snarkjs.groth16.verify(vKey, publicSignals, proof);
    if (!valid) throw new Error("Invalid proof");
    this.spentNullifiers.add(nullifier);
    return true;
  }
}
```

## Pitfalls to Avoid

1. **Under-constraining circuits**: The most dangerous bug — if a signal is used in a computation but not constrained with `===`, the prover can set it to anything. Every output signal that should equal something must have an explicit equality constraint. Use the `--sym` flag and audit constraints with `snarkjs r1cs print` to verify all critical signals are constrained. Under-constrained circuits allow malicious proofs.

2. **Using insecure hash functions**: Standard SHA-256 is extremely expensive in arithmetic circuits (millions of constraints). Use ZK-friendly hash functions — Poseidon (from circomlib) requires ~220 constraints vs SHA-256's ~25,000+. Importing `poseidon.circom` instead of a SHA wrapper reduces proving time by 100x and makes circuits feasible for real-time applications.

3. **Skipping the trusted setup ceremony**: Groth16 proofs require a circuit-specific trusted setup. The toxic waste from `snarkjs zkey contribute` must be destroyed by every contributor. For production, either run a multi-party ceremony with enough participants that collusion is implausible, or switch to PLONK/FFLONK which have a universal (non-circuit-specific) setup — compromising one PLONK setup doesn't affect the security of other circuits.

## Related Skills

- `end-to-end-encryption` — Traditional encryption patterns complementary to ZKP
- `blockchain-integration` — Deploying ZK verifier contracts on EVM chains
- `cryptography-fundamentals` — Elliptic curves, pairing-based crypto underlying ZKPs
- `api-security-hardening` — Privacy-preserving authentication patterns

## GitNexus Index

```json
{
  "skill": "zero-knowledge-proofs",
  "category": "security",
  "triggers": ["zero knowledge proof", "ZKP", "zk-snark", "circom", "snarkjs", "groth16", "PLONK", "merkle proof zkp", "ZK circuit", "nullifier", "proof generation", "trusted setup", "r1cs"],
  "outputs": ["RangeProof template", "MerkleProof circuit", "snarkjs groth16.fullProve", "snarkjs groth16.verify", "ZKMerkleTree", "NullifierRegistry", "poseidon hash circuit", "exportSolidityCallData"],
  "complexity": "high",
  "tools": ["circom", "snarkjs", "circomlibjs", "poseidon", "groth16", "plonk", "node.js"]
}
```
