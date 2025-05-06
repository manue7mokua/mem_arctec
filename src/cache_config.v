// Cache Configuration File
// Contains parameters and macros for the two-level cache hierarchy

// Debug macro to print configuration
`define DEBUG_CONFIG \
initial begin \
  $display("CACHE CONFIG DEBUG:"); \
  $display("L1 Cache Mapping Type: %0d", `CACHE_MAPPING_L1); \
  $display("L2 Cache Mapping Type: %0d", `CACHE_MAPPING_L2); \
  $display("L1 Replacement Policy: %0d", `REPLACEMENT_POLICY_L1); \
  $display("L2 Replacement Policy: %0d", `REPLACEMENT_POLICY_L2); \
end

// Cache Sizes (in bytes)
`define L1_CACHE_SIZE 256  // 256 bytes
`define L2_CACHE_SIZE 512  // 512 bytes
`define MAIN_MEMORY_SIZE 2048  // 2048 bytes

// Block Sizes (in bytes)
`define L1_BLOCK_SIZE 16  // 16 bytes per block
`define L2_BLOCK_SIZE 32  // 32 bytes per block

// Mapping Types
`define DIRECT_MAPPED 0
`define TWO_WAY 1
`define FOUR_WAY 2

// Default mapping types for each cache level
// These will be overridden by command line if provided
`ifndef CACHE_MAPPING_L1
  `define CACHE_MAPPING_L1 `DIRECT_MAPPED
`endif

`ifndef CACHE_MAPPING_L2
  `define CACHE_MAPPING_L2 `DIRECT_MAPPED
`endif

// Replacement Policies
`define LRU 0  // Least Recently Used
`define RANDOM 1  // Random replacement

// Default replacement policies for each cache level
// These will be overridden by command line if provided
`ifndef REPLACEMENT_POLICY_L1
  `define REPLACEMENT_POLICY_L1 `LRU
`endif

`ifndef REPLACEMENT_POLICY_L2
  `define REPLACEMENT_POLICY_L2 `LRU
`endif

// Access Latencies (in clock cycles)
`define L1_LATENCY 1
`define L2_LATENCY 10
`define MEMORY_LATENCY 100

// Helper Functions and Macros

// Calculate log2(x) - used to determine address bit widths
`define LOG2(x) \
    ((x) <= 2) ? 1 : \
    ((x) <= 4) ? 2 : \
    ((x) <= 8) ? 3 : \
    ((x) <= 16) ? 4 : \
    ((x) <= 32) ? 5 : \
    ((x) <= 64) ? 6 : \
    ((x) <= 128) ? 7 : \
    ((x) <= 256) ? 8 : \
    ((x) <= 512) ? 9 : \
    ((x) <= 1024) ? 10 : \
    ((x) <= 2048) ? 11 : 12

// Compute the number of bits for block offset
`define COMPUTE_OFFSET_BITS(block_size) `LOG2(block_size)

// Compute the number of sets
`define COMPUTE_NUM_SETS(cache_size, block_size, mapping_type) \
    ((mapping_type == `DIRECT_MAPPED) ? ((cache_size) / (block_size)) : \
     (mapping_type == `TWO_WAY) ? ((cache_size) / (block_size) / 2) : \
     (mapping_type == `FOUR_WAY) ? ((cache_size) / (block_size) / 4) : \
     ((cache_size) / (block_size)))

// Compute the number of bits for set index
`define COMPUTE_INDEX_BITS(num_sets) `LOG2(num_sets)

// Compute the number of bits for tag
`define COMPUTE_TAG_BITS(addr_width, index_bits, offset_bits) ((addr_width) - (index_bits) - (offset_bits))

// Debug macro for address bit fields (can be added to display statements)
`define DEBUG_ADDR_FIELDS(addr, tag_bits, index_bits, offset_bits) \
    $display("Address: %h, Tag: %h, Index: %h, Offset: %h", \
             addr, \
             (addr >> (index_bits + offset_bits)), \
             ((addr >> offset_bits) & ((1 << index_bits) - 1)), \
             (addr & ((1 << offset_bits) - 1))) 