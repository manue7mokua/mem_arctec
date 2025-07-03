# Two-Level Cache Hierarchy Simulation Project

## Overview

This project is a **Verilog-based simulation of a two-level memory cache hierarchy** designed for educational and research purposes. It models the behavior of L1 and L2 caches with configurable mapping strategies and replacement policies, allowing users to study and compare different cache configurations and their performance characteristics.

## Project Purpose

The simulation serves multiple purposes:
- **Educational**: Helps students understand cache hierarchy concepts, memory access patterns, and performance metrics
- **Research**: Enables experimentation with different cache configurations
- **Performance Analysis**: Provides detailed metrics including hit rates and Average Memory Access Time (AMAT)

## System Architecture

The cache hierarchy consists of three main memory levels:

```
CPU ↔ L1 Cache (256B, 16B blocks) ↔ L2 Cache (512B, 32B blocks) ↔ Main Memory (2048B)
```

### Memory Specifications
- **L1 Cache**: 256 bytes total, 16-byte blocks, 1 cycle latency
- **L2 Cache**: 512 bytes total, 32-byte blocks, 10 cycle latency  
- **Main Memory**: 2048 bytes total, 100 cycle latency

## Key Features

### 1. **Configurable Mapping Strategies**
- **Direct-Mapped**: Each memory block maps to exactly one cache location
- **2-Way Set Associative**: Each memory block can map to one of two locations within a set
- **4-Way Set Associative**: Each memory block can map to one of four locations within a set

### 2. **Replacement Policies**
- **LRU (Least Recently Used)**: Replaces the block that was accessed longest ago
- **Random**: Replaces a randomly selected block from the set

### 3. **Performance Metrics**
- Hit/miss counters for both L1 and L2 caches
- Hit rate calculations (percentage of successful cache accesses)
- AMAT calculation using the formula: `AMAT = L1_latency + L1_miss_rate × (L2_latency + L2_miss_rate × Memory_latency)`

## Project Structure & Components

### Core Verilog Modules

#### 1. **`cache_config.v`** - Configuration Management
- Defines cache sizes, block sizes, and latencies
- Contains mapping type constants (`DIRECT_MAPPED`, `TWO_WAY`, `FOUR_WAY`)
- Provides macros for calculating address bit partitioning
- Handles compile-time configuration via command-line defines

#### 2. **`top.v`** - System Integration
- Connects all components (CPU, L1, L2, Main Memory)
- Handles data promotion between cache levels
- Manages performance counters
- Implements cache miss handling logic

#### 3. **`l1_cache.v`** & **`l2_cache.v`** - Cache Implementations
- Parameterizable cache modules supporting all mapping types
- Address bit partitioning (tag, index, offset)
- Hit/miss detection logic
- LRU counter management for associative caches
- Data promotion interfaces

#### 4. **`cpu.v`** - Memory Access Generator
- Reads memory addresses from trace files
- Simulates CPU memory access patterns
- Provides addresses to the cache hierarchy

#### 5. **`main_memory.v`** - Memory Model
- Simple main memory implementation
- Provides data on cache misses

### Test Infrastructure

#### **`testbench.v`** - Simulation Controller
- Sets up the simulation environment
- Generates clock signals
- Monitors and reports performance metrics
- Creates VCD waveform files for analysis

#### **`test_trace.txt`** - Memory Access Patterns
Contains diverse access patterns including:
- **Sequential access**: Consecutive memory addresses
- **Repeated access**: Same addresses multiple times (tests cache hits)
- **Stride access**: Regular interval patterns
- **Random access**: Pseudo-random address patterns
- **Loop patterns**: Repeated small sequences
- **Interleaved access**: Alternating between different regions

## How It Works

### 1. **Address Processing**
Each 11-bit address (covering 0-2047 byte range) is divided into:
- **Tag bits**: Identify the specific memory block
- **Index bits**: Determine which cache set to access
- **Offset bits**: Specify byte position within a block

### 2. **Cache Access Flow**
1. CPU generates memory address
2. L1 cache checks for hit using tag comparison
3. If L1 hit: Return data immediately
4. If L1 miss: Check L2 cache
5. If L2 hit: Promote data to L1, return data
6. If L2 miss: Fetch from main memory, populate both caches

### 3. **Data Promotion Strategy**
- **L1 miss, L2 hit**: Data promoted from L2 to L1
- **Both miss**: Data fetched from memory and placed in both L1 and L2
- Uses replacement policies to determine which cache line to evict

### 4. **Performance Tracking**
The system continuously monitors:
- Cache hits and misses at each level
- Real-time hit rate calculations
- AMAT computation based on access latencies

## Build and Execution System

### **Makefile Targets**
The comprehensive Makefile provides multiple pre-configured scenarios:

- `make direct_mapped`: Direct-mapped caches
- `make two_way_lru`: 2-way associative with LRU
- `make four_way_random`: 4-way associative with random replacement
- `make mixed`: Different configurations for L1 and L2
- `make compare`: Runs all configurations and compares results

### **Custom Configuration**
Users can override default settings using compiler defines:
```bash
iverilog -DCACHE_MAPPING_L1=1 -DCACHE_MAPPING_L2=2 \
         -DREPLACEMENT_POLICY_L1=0 -DREPLACEMENT_POLICY_L2=1 \
         -o cache_sim test/testbench.v src/*.v
```

## Output and Analysis

### **Console Output**
- Real-time access logging with hit/miss status
- Data promotion notifications
- Progressive performance statistics
- Final comprehensive metrics

### **Waveform Generation**
- VCD files for GTKWave or web-based viewers
- Detailed signal timing analysis
- Visual cache behavior examination

### **Performance Metrics**
The simulation provides detailed analysis including:
- Raw hit/miss counts
- Hit rate percentages
- AMAT calculations
- Comparative performance across configurations

## Educational Value

This simulation is particularly valuable for understanding:
- **Cache locality principles**: How spatial and temporal locality affect performance
- **Associativity trade-offs**: Comparing direct-mapped vs. set-associative caches
- **Replacement policy impact**: LRU vs. Random replacement effectiveness
- **Memory hierarchy benefits**: Multi-level cache performance advantages
- **Address mapping**: How memory addresses map to cache locations

## Extensibility

The modular design allows for easy extensions:
- Additional replacement policies
- Different cache sizes or block sizes
- More cache levels
- Various memory access patterns
- Performance optimization studies

This project serves as an excellent foundation for computer architecture education and cache performance research, providing both theoretical understanding and practical implementation experience with memory hierarchy systems.