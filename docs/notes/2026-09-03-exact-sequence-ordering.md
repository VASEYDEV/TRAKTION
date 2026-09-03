# Exact sequence ordering implementation

Task 0007 begins Milestone 2 with a deliberately narrow API. The engine now
accepts unordered captures only through `reconstructExactUnordered`, builds
exact directed overlap evidence, and requires one complete path. The existing
supplied-order API remains the compatibility/default path.

The implementation sorts nodes by capture identity before graph traversal,
stops after finding two complete paths, and reports those two paths as a stable
ambiguity diagnostic. It reserves near-exact graph scoring for a later task
because a local error ranking is not a proof of global documentary order.

Graph examination is fail-closed under a separate pixel-comparison budget. The
budget charges the complete potential overlap area for every ordered pair
before examining that pair, which is conservative and prevents a result from a
partially explored graph.

Regression coverage exercises shuffled exact reconstruction and pixel equality,
input-permutation determinism, missing coverage, bidirectional ambiguity,
ordering-budget exhaustion, overlap-search limits, and new failure Codable
contracts.
