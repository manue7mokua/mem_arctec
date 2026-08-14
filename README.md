# Two-Level Cache Hierarchy Simulation

This project implements a cycle-accurate Verilog simulation of a two-level memory cache hierarchy. A ready/valid request protocol serializes each trace request through timed L1, L2, memory, refill, and dirty-writeback states, so reported cycles are elapsed transaction cycles rather than a post-processed estimate.

## Cache Specifications

- **L1 Cache**: 256 bytes with 16-byte blocks
- **L2 Cache**: 512 bytes with 32-byte blocks
- **Main Memory**: 2048 bytes

## Features

- **Configurable Mapping Strategies**:

  - Direct-Mapped
  - 2-Way Set Associative
  - 4-Way Set Associative

- **Replacement Policies**:

  - LRU (Least Recently Used)
  - Random

- **Performance Tracking**:

  - L1 and L2 hit/miss counts
  - Read and write request counts
  - Dirty writeback counts
  - Actual transaction and stall cycles
  - Hit rates
  - Analytical demand AMAT and measured average transaction cost

- **Transaction Behavior**:

  - CPU ready/valid backpressure
  - One response for every accepted request
  - Completion-driven simulation termination
  - Dirty L1 writeback to L2 and dirty L2 writeback to memory
  - Optional explicit write values and read-response checking

- **Access Latencies**:
  - L1 Cache: 1 cycle
  - L2 Cache: 10 cycles
  - Main Memory: 100 cycles

## Project Structure

- `src/`

  - `cache_config.v`: Configuration parameters for the cache hierarchy
  - `cache_level.v`: Shared parameterized lookup, replacement, storage, and eviction logic
  - `l1_cache.v`: L1 cache implementation
  - `l2_cache.v`: L2 cache implementation
  - `main_memory.v`: Main memory implementation
  - `cpu.v`: CPU module that loads memory traces
  - `top.v`: Top-level module connecting all components

- `test/`
  - `testbench.v`: Testbench to run and evaluate the simulation
  - `test_trace.txt`: Read/write memory access trace file
  - `generate_trace.py`: Generates larger mixed read/write traces
  - `generate_simple_trace.py`: Generates simple sequential read/write traces
  - `data_trace.txt`: Explicit-value trace that forces dirty evictions
  - `latency_trace.txt`: Cold-miss/warm-hit latency regression
  - `run_regression.py`: Compiles and verifies every supported configuration

## How to Run

1. Compile the Verilog files:

```
iverilog -o cache_sim test/testbench.v src/*.v
```

2. Run the simulation:

```
vvp cache_sim +TRACE=test/test_trace.txt
```

3. Run the complete regression matrix:

```
make regression
```

4. Generate and view a waveform when needed:

```
vvp cache_sim +TRACE=test/test_trace.txt +VCD
gtkwave output.vcd
```

Or upload the VCD file to [vc.drom.io](https://vc.drom.io/) for viewing in a browser.

## Customizing Cache Configuration

You can customize the cache configuration by modifying `src/cache_config.v` or by passing compiler defines:

```
# Direct-mapped caches
iverilog -DCACHE_MAPPING_L1=0 -DCACHE_MAPPING_L2=0 -o cache_sim test/testbench.v src/*.v

# 2-way set associative with LRU
iverilog -DCACHE_MAPPING_L1=1 -DCACHE_MAPPING_L2=1 -DREPLACEMENT_POLICY_L1=0 -DREPLACEMENT_POLICY_L2=0 -o cache_sim test/testbench.v src/*.v

# 4-way set associative with Random replacement
iverilog -DCACHE_MAPPING_L1=2 -DCACHE_MAPPING_L2=2 -DREPLACEMENT_POLICY_L1=1 -DREPLACEMENT_POLICY_L2=1 -o cache_sim test/testbench.v src/*.v

# Mix and match different configurations for L1 and L2
iverilog -DCACHE_MAPPING_L1=1 -DCACHE_MAPPING_L2=2 -DREPLACEMENT_POLICY_L1=0 -DREPLACEMENT_POLICY_L2=1 -o cache_sim test/testbench.v src/*.v
```

## Interpreting Results

The simulation provides detailed performance metrics:

- **Hit/Miss Counters**: Raw count of cache hits and misses at each level
- **Request Mix**: Total read and write requests emitted by the CPU trace reader
- **Dirty Writebacks**: Number of dirty cache-line evictions that require a writeback
- **Cycle Counters**: Clock cycles spent servicing transactions, including lookup, refill, and dirty-writeback work
- **Hit Rates**: Percentage of accesses that resulted in a hit
- **Measured Average Transaction Cost**: Actual transaction cycles divided by completed requests
- **AMAT (Average Memory Access Time)**: Calculated based on the formula:
  - AMAT = L1 access time + L1 miss rate * (L2 access time + L2 miss rate * Memory access time)

The simulation also includes detailed console output showing:

- Each memory access with address, hit/miss status
- Data promotion between cache levels
- Replacement decisions in associative caches

Pass `+VERBOSE` to emit per-request completion records. Every run emits a compact, machine-readable `RESULT` line for regression tooling. Waveform output is opt-in through `+VCD`.

## Testing Different Access Patterns

The `test_trace.txt` file contains various read/write memory access patterns to evaluate cache performance:

- Sequential access
- Repeated access
- Stride access
- Random access
- Loop patterns
- Interleaved access
- Write-heavy conflict patterns

Trace lines use these formats:

```
R 010
W 110
W 210 DEADBEEF
```

The first token is the operation (`R` for read or `W` for write) and the second token is the hexadecimal address. A write may include a hexadecimal 32-bit value. Writes without a value receive a deterministic value derived from the address. Legacy address-only lines are still treated as reads.

## Implementation Details

### Address Bit Partitioning

- For an 11-bit address (0-2047), the bits are divided into:
  - Tag: Most significant bits
  - Index: Middle bits that determine the cache set
  - Offset: Least significant bits that determine the byte within a block

The exact bit partitioning is calculated dynamically based on the cache configuration.

### Data Promotion

- When there's an L1 miss but L2 hit, data is promoted from L2 to L1
- When there's both an L1 and L2 miss, data is fetched from main memory and placed in both caches

Each modeled cache block currently carries one 32-bit payload. The explicit-data regression therefore uses block-aligned addresses.

### Write Behavior

- The simulator uses write-allocate behavior: a write miss allocates the requested line into L1
- L1 writes become dirty and are written into L2 when evicted
- Dirty L2 victims are written into main memory before the request completes
- Writeback latency contributes to the measured transaction cost

### Cycle-Accurate Controller

The CPU holds a request until the hierarchy accepts it. The controller then moves through lookup, wait, refill, eviction-check, and writeback states. Base delays are:

- L1 lookup: 1 cycle
- L2 lookup: 10 cycles
- Main-memory operation: 100 cycles

Refill and eviction-controller states add real clock cycles. Stall cycles are all transaction cycles beyond the first request-service cycle. The trace finishes only after its final accepted request has produced a response.

The regression suite checks that a cold memory access completes in 115 cycles with the current refill controller and that the immediately repeated L1 hit completes in 1 cycle.

### Cache Replacement

- In direct-mapped caches, the block is simply overwritten
- In set associative caches, replacement is based on the configured policy:
  - LRU: Replaces the least recently used block in the set
  - Random: Replaces a random block in the set

## Performance Comparison

Running the simulation with different configurations allows comparison of:

- Different mapping strategies (direct-mapped vs. set associative)
- Different replacement policies (LRU vs. Random)
- Different associativity levels (2-way vs. 4-way)

The most efficient configuration depends on the memory access pattern.
