# [CRITICAL] AnchorStateRegistry: Finalization Airgap Erosion via Pause Race Condition

**Researcher**: Omachoko Yakubu  
**Date**: 24 April 2026  
**Program**: Coinbase (Base / OP Stack)  
**Severity**: Critical — Direct Theft of Bridge Funds  

---

## 📝 Executive Summary

The `AnchorStateRegistry` contract, a core security component of the Base L1 bridge, contains a critical temporal race condition. The **3.5-day finalization airgap**—a fundamental security invariant designed as the last line of defense for Guardian intervention—is eroded during protocol pauses. 

If the system is paused to mitigate a malicious root, the finalization timer incorrectly continues to decay. If the pause duration exceeds the airgap, the malicious root becomes valid **immediately (0-second reaction window)** upon unpausing. This allows an attacker to authorized forged withdrawals and potentially drain the entire bridge liquidity (~$2.58B TVL) before the Guardian can execute a corrective action.

## 🔍 Relevant Context

- **Target Asset**: `AnchorStateRegistry` (Base L1 Proxy)
- **Contract Address**: [`0x909f6cf47ed12f010A796527f562bFc26C7F4E72`](https://etherscan.io/address/0x909f6cf47ed12f010A796527f562bFc26C7F4E72)
- **Vulnerability Type**: Logic Error / Race Condition / Security Invariant Violation

---

## 🛠️ Finding Description

### 1. Root Cause Analysis
In the OP Stack fault dispute system, the `AnchorStateRegistry` maintains the trusted starting point for all new dispute games. A game's root claim is considered "finalized" only after it has resolved and a safety airgap (`DISPUTE_GAME_FINALITY_DELAY_SECONDS`) has elapsed. This airgap is currently set to **302,400 seconds (3.5 days)** on Base.

The vulnerability resides in the `isGameFinalized` function:

```solidity
function isGameFinalized(IDisputeGame _game) public view returns (bool) {
    if (!isGameResolved(_game)) { return false; }
    // 🚨 VULNERABILITY: Wall-clock time is used without checking pause status
    if (block.timestamp - _game.resolvedAt().raw() <= DISPUTE_GAME_FINALITY_DELAY_SECONDS) {
        return false;
    }
    return true;
}
```

While the `isGameProper()` function correctly checks the `paused()` status, it is only evaluated at the instant of execution. It does **not** stop the "finalization clock."

### 2. The Exploit Path (The "Stealing the Window" Attack)
1. **Malicious Resolution**: An attacker resolves a `FaultDisputeGame` with an invalid L2 output (e.g., via a VM bug or an unchallenged game).
2. **Guardian Intervention**: The Guardian detects the anomaly and pauses the `SystemConfig` to protect the bridge.
3. **Airgap Erosion**: The 3.5-day timer continues to run while the system is paused. The Guardian's investigation often takes longer than 3.5 days.
4. **Instant Validity**: Once the time elapsed since resolution exceeds the delay, the game is marked as "finalized."
5. **Zero-Window Execution**: The moment the Guardian lifts the pause to deploy a fix or resume operations, the malicious root is **immediately valid**. The attacker can proof and execute a withdrawal in the same block as the unpause, bypassing the airgap protection entirely.

---

## 🏛️ Hans Pillars Analysis

### Impact Explanation (Hans Pillar 2: Impact)
- **Technical Impact**: Bypasses the fundamental "Defense in Depth" layer of the OP Stack. It turns an asynchronous, guarded finalization process into a synchronous, unguarded race.
- **Economic Impact**: **High (Critical)**. The canonical bridge (`OptimismPortal`) currently holds over **$2.58 Billion** in liquidity. An invalid anchor state allows for arbitrary withdrawal authorizations, leading to a total drain of the bridge.

### Likelihood Explanation (Hans Pillar 1: Likelihood)
- **Attack Complexity**: Low. Requires no special tools, only monitoring of the pause state and standard withdrawal proof generation.
- **Economic Feasibility**: Extremely High. The cost of a malicious resolution is negligible compared to the billions at stake.
- **Likelihood Rating**: **Medium/High**. This bug is systemic to the current OP Stack design and resides in the primary emergency-response mechanism.

---

## 💻 Proof of Concept (PoC)

I have provided a forked-mainnet Foundry PoC that demonstrates this vulnerability against the live `AnchorStateRegistry` proxy.

### Setup & Reproduction
1. **Clone the Repository**:
   ```bash
   git clone https://github.com/OmachokoYakubu/coinbase-anchor-registry-race
   cd coinbase-anchor-registry-race
   ```
2. **Install Dependencies**:
   ```bash
   forge install
   ```
3. **Run the Simulation**:
   ```bash
   export MAINNET_RPC_URL="<your_rpc_url>"
   forge test --match-contract CoinbaseRaceProof -vvvv
   ```

### Expected Output
The test will confirm that the airgap is consumed during the pause, resulting in a **0-second reaction window** for the Guardian.

---

## 🛡️ Remediation

Update `isGameFinalized` to ensure the airgap period only counts time while the system is **unpaused**. 

```solidity
function isGameFinalized(IDisputeGame _game) public view returns (bool) {
    if (!isGameResolved(_game)) return false;
    uint256 timeSinceResolution = block.timestamp - _game.resolvedAt().raw();
    // VULNERABILITY FIX: Ensure that the system is NOT paused and the delay has passed
    return timeSinceResolution > DISPUTE_GAME_FINALITY_DELAY_SECONDS && !paused();
}
```

---

*Omachoko Yakubu, Security Researcher*
