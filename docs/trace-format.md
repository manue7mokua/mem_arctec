# Trace Format

Each non-comment line describes one 32-bit request against an 11-bit byte address:

```text
R <hex-address>
W <hex-address> [hex-data]
```

Examples:

```text
R 014
W 01C DEADBEEF
W 005 AAAAAAAA
```

Writes without explicit data receive a deterministic value derived from their address. Address-only legacy lines are reads.

## Alignment

Requests select the containing 32-bit word. Addresses `004` through `007` therefore access the same word, while `008` selects the next word. The original trace address is retained in the response for diagnostics.

## Runtime options

- `+TRACE=<path>` selects a trace file.
- `+CHECK_DATA` enables the testbench scoreboard.
- `+VERBOSE` prints every completed request and memory-line write.
- `+VCD` writes `output.vcd`.
