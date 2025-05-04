module l1_cache(input clk, input [10:0] address, output reg hit, output reg miss, output reg [31:0] data_out, 
  input promote_data, input [31:0] promotion_data);
  // Use a simpler include path that will work with the -I flag
  `include "src/cache_config.v" 
  
  parameter CACHE_SIZE = `L1_CACHE_SIZE;
  parameter BLOCK_SIZE = `L1_BLOCK_SIZE;
  parameter MAPPING_TYPE = `CACHE_MAPPING_L1;
  parameter REPLACEMENT_POLICY = `REPLACEMENT_POLICY_L1;
  
  // Calculate the number of ways based on the mapping type
  localparam WAYS = (MAPPING_TYPE == `DIRECT_MAPPED) ? 1 :
                   (MAPPING_TYPE == `TWO_WAY) ? 2 : 
                   (MAPPING_TYPE == `FOUR_WAY) ? 4 : 1;
                   
  // Calculate the number of sets using the macro
  localparam NUM_SETS = `COMPUTE_NUM_SETS(CACHE_SIZE, BLOCK_SIZE, MAPPING_TYPE);
  
  // Calculate address bit partitioning using the macros
  localparam OFFSET_BITS = `COMPUTE_OFFSET_BITS(BLOCK_SIZE);
  localparam INDEX_BITS = `COMPUTE_INDEX_BITS(NUM_SETS);
  localparam TAG_BITS = `COMPUTE_TAG_BITS(11, INDEX_BITS, OFFSET_BITS);
  
  // Extract address components
  wire [OFFSET_BITS-1:0] block_offset = address[OFFSET_BITS-1:0];
  wire [INDEX_BITS-1:0] index = address[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
  wire [TAG_BITS-1:0] tag = address[10:OFFSET_BITS+INDEX_BITS];
  
  // Cache storage
  reg valid[NUM_SETS-1:0][WAYS-1:0];
  reg [TAG_BITS-1:0] tags[NUM_SETS-1:0][WAYS-1:0];
  reg [31:0] data[NUM_SETS-1:0][WAYS-1:0];
  
  // LRU tracking (only used if REPLACEMENT_POLICY is LRU)
  // For 2-way: 1 bit per set (0: way 0 is LRU, 1: way 1 is LRU)
  // For 4-way: 2 bits per way (higher value = more recently used, 0 = LRU)
  reg [WAYS-1:0] lru_counters[NUM_SETS-1:0][WAYS-1:0];
  
  // Variables for internal logic
  integer i, j, hit_way, lru_way, rnd_way;
  reg cache_hit;
  
  // Initialize cache on reset
  initial begin
    for (i = 0; i < NUM_SETS; i = i + 1) begin
      for (j = 0; j < WAYS; j = j + 1) begin
        valid[i][j] = 0;
        lru_counters[i][j] = 0;
      end
    end
    hit = 0;
    miss = 0;
  end
  
  // Random number generation for RANDOM replacement policy
  function integer random_way;
    input integer max_way;
    begin
      random_way = $urandom % max_way;
    end
  endfunction
  
  // LRU way selection
  function integer find_lru_way;
    input integer set_index;
    reg [WAYS-1:0] min_counter;
    integer min_index, k;
    begin
      min_counter = lru_counters[set_index][0];
      min_index = 0;
      
      for (k = 1; k < WAYS; k = k + 1) begin
        if (lru_counters[set_index][k] < min_counter) begin
          min_counter = lru_counters[set_index][k];
          min_index = k;
        end
      end
      
      find_lru_way = min_index;
    end
  endfunction
  
  // Update LRU counters
  task update_lru_counters;
    input integer set_index;
    input integer accessed_way;
    integer k;
    begin
      if (MAPPING_TYPE != `DIRECT_MAPPED && REPLACEMENT_POLICY == `LRU) begin
        // Decrement all counters
        for (k = 0; k < WAYS; k = k + 1) begin
          if (lru_counters[set_index][k] > 0)
            lru_counters[set_index][k] = lru_counters[set_index][k] - 1;
        end
        
        // Set the accessed way's counter to max value (most recently used)
        lru_counters[set_index][accessed_way] = WAYS - 1;
      end
    end
  endtask
  
  // Function to select a way for replacement or promotion
  function integer select_replacement_way;
    input integer set_index;
    integer selected_way, k;
    begin
      // First check for invalid entries
      selected_way = -1;
      for (k = 0; k < WAYS; k = k + 1) begin
        if (!valid[set_index][k]) begin
          selected_way = k;
          k = WAYS; // Break the loop
        end
      end
      
      // If no invalid entry found, use replacement policy
      if (selected_way == -1) begin
        if (REPLACEMENT_POLICY == `LRU) begin
          selected_way = find_lru_way(set_index);
        end else begin
          // RANDOM replacement policy
          selected_way = random_way(WAYS);
        end
      end
      
      select_replacement_way = selected_way;
    end
  endfunction
  
  // Two-part design: Handle hit/miss checking on address changes, handle promotion on clock edge
  
  // First part: Check for hits/misses whenever address changes or on posedge clk
  always @(address) begin
    // Display debug information for address mapping
    `DEBUG_ADDR_FIELDS(address, TAG_BITS, INDEX_BITS, OFFSET_BITS);
    
    // Default values
    hit_way = -1;
    cache_hit = 0;
    
    // Check all ways for a hit
    for (i = 0; i < WAYS; i = i + 1) begin
      if (valid[index][i] && tags[index][i] == tag) begin
        hit_way = i;
        cache_hit = 1;
      end
    end
    
    if (cache_hit) begin
      // Cache hit
      hit = 1;
      miss = 0;
      data_out = data[index][hit_way];
      $display("L1 Cache HIT: Address=%h, Index=%h, Tag=%h, Way=%0d", address, index, tag, hit_way);
    end else begin
      // Cache miss
      hit = 0;
      miss = 1;
      data_out = 0;
      $display("L1 Cache MISS: Address=%h, Index=%h, Tag=%h", address, index, tag);
    end
  end
  
  // Second part: Handle data promotion on clock edge
  always @(posedge clk) begin
    // Only update if either we found a hit earlier or we're promoting data
    if (promote_data) begin
      lru_way = select_replacement_way(index);
      $display("L1 Cache: Promoting data from L2, Address=%h, Set=%h, Way=%0d, Tag=%h", 
               address, index, lru_way, tag);
      
      // Update cache with promotion data
      valid[index][lru_way] <= 1;
      tags[index][lru_way] <= tag;
      data[index][lru_way] <= promotion_data;
      
      // Update LRU counters for the promoted data
      update_lru_counters(index, lru_way);
    end
    else if (cache_hit) begin
      // Update LRU counters on hit
      update_lru_counters(index, hit_way);
    end
  end
endmodule

