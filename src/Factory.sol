// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {Pair} from "./Pair.sol";

/// @title Permissionless deterministic pool registry
/// @notice No owner, allowlist, fee switch, upgrade or rescue authority.
contract Factory {
    error InvalidTokens();
    error PairExists();
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 index);

    /// @notice Create the single canonical pair for two deployed tokens.
    function createPair(address a, address b) external returns (address pair) {
        if (a == b || a == address(0) || b == address(0) || a.code.length == 0 || b.code.length == 0) {
            revert InvalidTokens();
        }
        (address t0, address t1) = a < b ? (a, b) : (b, a);
        if (getPair[t0][t1] != address(0)) revert PairExists();
        pair = address(new Pair{salt: keccak256(abi.encode(t0, t1))}(t0, t1));
        getPair[t0][t1] = pair;
        getPair[t1][t0] = pair;
        allPairs.push(pair);
        emit PairCreated(t0, t1, pair, allPairs.length);
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }
}
