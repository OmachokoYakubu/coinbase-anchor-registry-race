# Base Bridge Vulnerability: AnchorStateRegistry Airgap Erosion

**Researcher**: Omachoko Yakubu  
**Date**: 24 April 2026  
**Program**: Coinbase (Base / OP Stack)  
**Severity**: Critical — Total Bridge Liquidity at Risk  

---

## Overview

This repository contains a high-fidelity Proof-of-Concept (PoC) for a Critical race condition discovered in the Base AnchorStateRegistry. 

The vulnerability allows a malicious dispute game to bypass the 3.5-day finalization airgap if the protocol is paused during the airgap period. This leads to a scenario where an invalid root can be finalized and executed immediately (0-second reaction window) upon unpausing the system, potentially resulting in a total drain of the Base L1 Bridge (~$2.58B TVL).

**Target Contract**: [AnchorStateRegistry](https://etherscan.io/address/0x909f6cf47ed12f010A796527f562bFc26C7F4E72) — `0x909f6cf47ed12f010A796527f562bFc26C7F4E72` (Ethereum Mainnet)

---

## Repository Contents

| File | Description |
|------|-------------|
| `CANTINA_SUBMISSION.md` | Main bug report covering the vulnerability, impact analysis, Hans Pillars, and recommendation. |
| `test/CoinbaseRaceProof.t.sol` | Foundry PoC demonstrating the airgap erosion on a forked mainnet. |
| `src/Interfaces.sol` | Clean interfaces for interacting with the OP Stack contracts. |
| `TRIAGE_DEFENSE_PLAYBOOK.md` | Clinical defense strategy for potential triage pushback. |
| `foundry.toml` | Project configuration. |

---

## Setup & Reproduction

### Prerequisites
- [Foundry](https://getfoundry.sh/) installed.
- Internet connection (the tests fork live Ethereum state).

### Clone and Run
```bash
# 1. Clone this repository
git clone https://github.com/OmachokoYakubu/coinbase-anchor-registry-race

# 2. Navigate into the project directory
cd coinbase-anchor-registry-race

# 3. Install dependencies
forge install

# 4. Set your Ethereum mainnet RPC
export MAINNET_RPC_URL="https://mainnet.infura.io/v3/<YOUR_KEY>"

# 5. Run the exploit simulation
forge test --match-contract CoinbaseRaceProof -vvvv
```

---

## PoC Breakdown

The simulation performs the following atomic steps on a mainnet fork:
1. **Mock Resolution**: Simulates a malicious FaultDisputeGame resolving at the current block.
2. **Mock Pause**: Simulates the Guardian's emergency response (pausing the system).
3. **Timer Decay**: Warps time by 3.5 days.
4. **Vulnerability Proof**: Demonstrates that isGameFinalized incorrectly returns true while the system is still paused.
5. **Exploit Execution**: Mocks the unpause transaction and proves the game is immediately valid, leaving the Guardian with no time to intervene.

All test output includes clearly labeled [CONFIRMED] markers to highlight successful attack steps.

---

## Remediation Strategy

The vulnerability is rooted in the use of wall-clock time (block.timestamp) without accounting for protocol status. The proposed fix ensures that the airgap only counts time while the protocol is active (!paused()), preserving the Defense in Depth security model.

---

*Omachoko Yakubu, Security Researcher*
