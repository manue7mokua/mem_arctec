# Two-Level Cache Hierarchy Simulation

This project implements a Verilog simulation of a two-level memory cache hierarchy with configurable mapping strategies, replacement policies, read/write traces, write-back dirty state, and modeled access-cycle accounting.

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
  - Total modeled access cycles and stall cycles
  - Hit rates
  - Average Memory Access Time (AMAT) calculation

- **Access Latencies**:
  - L1 Cache: 1 cycle
  - L2 Cache: 10 cycles
  - Main Memory: 100 cycles

## Project Structure

- `src/`

  - `cache_config.v`: Configuration parameters for the cache hierarchy
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

## How to Run

1. Compile the Verilog files:

```
iverilog -o cache_sim test/testbench.v src/*.v
```

2. Run the simulation:

```
vvp cache_sim
```

3. View waveforms (if needed):

```
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
- **Cycle Counters**: Total modeled access cycles and stall cycles from L1/L2/memory latency
- **Hit Rates**: Percentage of accesses that resulted in a hit
- **Measured Average Access Cost**: Total modeled access cycles divided by total requests
- **AMAT (Average Memory Access Time)**: Calculated based on the formula:
  - AMAT = L1 access time + L1 miss rate * (L2 access time + L2 miss rate * Memory access time)

The simulation also includes detailed console output showing:

- Each memory access with address, hit/miss status
- Data promotion between cache levels
- Replacement decisions in associative caches

## Testing Different Access Patterns

The `test_trace.txt` file contains various read/write memory access patterns to evaluate cache performance:

- Sequential access
- Repeated access
- Stride access
- Random access
- Loop patterns
- Interleaved access
- Write-heavy conflict patterns

Trace lines use this format:

```
R 010
W 110
```

The first token is the operation (`R` for read, `W` for write) and the second token is the hexadecimal address. Legacy address-only lines are still treated as reads.

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

### Write Behavior

- The simulator models write-allocate behavior: a write miss allocates the requested line into L1
- L1 tracks dirty bits for write-back behavior
- Dirty evictions increment the writeback counter, making write pressure visible in the final metrics

### Cycle Accounting

- Each valid request is classified by where it is served:
  - L1 hit: L1 latency
  - L1 miss and L2 hit: L1 + L2 latency
  - L1 miss and L2 miss: L1 + L2 + main memory latency
- Stall cycles are counted as all modeled access cycles beyond the L1 access latency

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
