# 🏛️ DAO Governance Playground

Welcome to my hands-on exploration of decentralized governance! This project is a working prototype of how DAOs (Decentralized Autonomous Organizations) can make collective decisions using smart contracts. Think of it like digital democracy powered by blockchain.

##  What's Inside the Toolbox

These are the key building blocks that make everything work:

### `GovToken.sol`
- This is your voting membership card, but digital!
- Holders get voting power proportional to their tokens
- Uses OpenZeppelin's battle-tested voting system

### `MyGovernor.sol`
- The brains of the operation - manages all proposals
- Handles everything from creating votes to counting them
- Simple rule: 1 token = 1 vote (like company shareholders)

### `TimeLock.sol`
- The safety mechanism that prevents rash decisions
- Makes sure no changes happen without community discussion
- Adds a mandatory 1-hour waiting period

### `Box.sol`
- Our practice dummy for testing proposals
- Imagine it's a community treasury that only changes when voters agree

## 🔧 Under the Hood

Built with:
- **Solidity (v0.8.19)** - The language of Ethereum smart contracts
- **Foundry** - A powerful toolkit for building and testing
- **OpenZeppelin** - Like LEGO blocks for secure contracts

## ✨ Why This Matters

Real-world DAO features we've implemented:
-  Fair voting where your voice matches your stake
-  Clear proposal journey from idea to execution
-  Minimum 4% participation required (no sneaky small-group decisions)
-  Built-in 1-hour "cooling off" period for safety
-  1-week voting periods so everyone has time to participate

##  Making Sure It Works

We've put it through its paces with:

```solidity
test/DAOGovernanceTest.t.sol  // Tests the whole voting process
test/MyGovernorTest.t.sol     // Focuses on the governance rules
