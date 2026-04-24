// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

enum GameStatus { IN_PROGRESS, CHALLENGER_WINS, DEFENDER_WINS }

type Timestamp is uint64;
type GameType is uint32;
type Claim is bytes32;
type Hash is bytes32;

interface IDisputeGame {
    function status() external view returns (GameStatus);
    function resolvedAt() external view returns (Timestamp);
    function createdAt() external view returns (Timestamp);
    function gameType() external view returns (GameType);
    function gameData() external view returns (GameType, Claim, bytes memory);
}

interface IAnchorStateRegistry {
    function disputeGameFinalityDelaySeconds() external view returns (uint256);
    function isGameFinalized(IDisputeGame _game) external view returns (bool);
    function isGameClaimValid(IDisputeGame _game) external view returns (bool);
    function paused() external view returns (bool);
}
