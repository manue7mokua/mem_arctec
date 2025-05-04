# Two-Level Cache Hierarchy Simulation

This project implements a two-level memory cache system in Verilog, simulating how memory access is handled in a hierarchical cache model. The goal is to evaluate the performance of various cache mapping techniques.

## System Description

- **CPU Address Space**: 11-bit address (total addressable memory = 2048 bytes)
- **Main Memory**: 2048 bytes
- **Level 1 (L1) Cache**:
  - Size: 256 bytes
  - Block size: 16 bytes
- **Level 2 (L2) Cache**:
  - Size: 512 bytes
  - Block size: 32 bytes

## Cache Implementations

1. **Direct-Mapped Cache** (Implemented)
2. **2-Way Set Associative Cache** (Planned)
3. **4-Way Set Associative Cache** (Planned)

## Performance Metrics

The simulation measures:

- Hit/Miss ratio for L1 and L2
- Access time simulation (L1: 1 cycle, L2: 10 cycles, Main memory: 100 cycles)
- Total average memory access time (AMAT)

## How to Run the Simulation

### Prerequisites

- [Icarus Verilog](https://iverilog.icarus.com/) for compilation and simulation
- Use [vc.drom.io](https://vc.drom.io/) for viewing waveforms

### Running the Simulation

1. Compile and run the simulation:

   ```
   make
   ```

2. View the results in the console output, which will show:

   - Memory access patterns
   - Cache hits and misses
   - Performance statistics including hit rates and AMAT

3. View the waveform (optional):
   - upload `output.vcd` to [vc.drom.io](https://vc.drom.io/) for online viewing.

## Test Trace

The simulation uses a test trace file (`test/test_trace.txt`) that contains a sequence of memory addresses to access. The trace includes various patterns:

- Sequential access
- Repeated access
- Stride access
- Random access
- Loop patterns

## Project Structure

- `src/` - Source code for the cache hierarchy
  - `cpu.v` - CPU model that reads addresses from the trace file
  - `l1_cache.v` - L1 cache implementation
  - `l2_cache.v` - L2 cache implementation
  - `main_memory.v` - Main memory implementation
  - `top.v` - Top-level module connecting all components
- `test/` - Test files
  - `test_trace.txt` - Memory address trace file
  - `testbench.v` - Testbench for simulation
- `Makefile` - Build automation
