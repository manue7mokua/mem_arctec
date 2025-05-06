module top(input clk, output [10:0] address, output hit_l1, output hit_l2, output [31:0] performance_counter_l1_hit, output [31:0] performance_counter_l1_miss, output [31:0] performance_counter_l2_hit, output [31:0] performance_counter_l2_miss);

  // Use a simpler include path that will work with the -I flag
  `include "src/cache_config.v"

  wire [10:0] cpu_address;
  wire [31:0] data_l1, data_l2, data_mem;
  wire miss_l1, miss_l2;
  
  // Print configuration debug info
  `DEBUG_CONFIG
  
  // Add wires for data promotion
  reg promote_l1_data;
  reg [31:0] promotion_l1_data;
  reg promote_l2_data;
  reg [31:0] promotion_l2_data;
  
  reg [31:0] l1_hit_count = 0;
  reg [31:0] l1_miss_count = 0;
  reg [31:0] l2_hit_count = 0;
  reg [31:0] l2_miss_count = 0;
  reg [31:0] mem_access_count = 0;
  
  // Delay registers to maintain correct temporal ordering
  reg [10:0] last_address;
  reg l1_missed = 0;
  reg l2_missed = 0;
  
  // Instantiate CPU with the trace file
  cpu cpu_inst (
    .clk(clk),
    .address(cpu_address)
  );
  
  // Instantiate L1 Cache with parameters
  l1_cache #(
    .CACHE_SIZE(`L1_CACHE_SIZE),
    .BLOCK_SIZE(`L1_BLOCK_SIZE),
    .MAPPING_TYPE(`CACHE_MAPPING_L1),
    .REPLACEMENT_POLICY(`REPLACEMENT_POLICY_L1)
  ) l1_cache_inst (
    .clk(clk),
    .address(cpu_address),
    .hit(hit_l1),
    .miss(miss_l1),
    .data_out(data_l1),
    .promote_data(promote_l1_data),
    .promotion_data(promotion_l1_data)
  );
  
  // Instantiate L2 Cache with parameters
  l2_cache #(
    .CACHE_SIZE(`L2_CACHE_SIZE),
    .BLOCK_SIZE(`L2_BLOCK_SIZE),
    .MAPPING_TYPE(`CACHE_MAPPING_L2),
    .REPLACEMENT_POLICY(`REPLACEMENT_POLICY_L2)
  ) l2_cache_inst (
    .clk(clk),
    .address(cpu_address),
    .l1_miss(miss_l1),
    .hit(hit_l2),
    .miss(miss_l2),
    .data_out(data_l2),
    .promote_data(promote_l2_data),
    .promotion_data(promotion_l2_data)
  );
  
  // Instantiate Main Memory
  main_memory main_memory_inst (
    .clk(clk),
    .address(cpu_address),
    .data_out(data_mem)
  );
  
  // Connect CPU address to output for display
  assign address = cpu_address;
  
  // Connect performance counters to outputs
  assign performance_counter_l1_hit = l1_hit_count;
  assign performance_counter_l1_miss = l1_miss_count;
  assign performance_counter_l2_hit = l2_hit_count;
  assign performance_counter_l2_miss = l2_miss_count;
  
  // Handle L1 and L2 cache hits/misses and update performance counters
  always @(posedge clk) begin
    last_address <= cpu_address;
    
    // Reset promotion signals by default
    promote_l1_data <= 0;
    promote_l2_data <= 0;
    
    // First, check for L1 hit/miss and update counters
    if (hit_l1) begin
      l1_hit_count <= l1_hit_count + 1;
      l1_missed <= 0;
    end else if (miss_l1) begin
      l1_miss_count <= l1_miss_count + 1;
      l1_missed <= 1;
    end
    
    // Then check L2 if there was an L1 miss
    if (l1_missed && hit_l2) begin
      l2_hit_count <= l2_hit_count + 1;
      l2_missed <= 0;
      
      // Promote from L2 to L1
      promote_l1_data <= 1;
      promotion_l1_data <= data_l2;
      $display("Promoting data from L2 to L1: Address=%h, Data=%h", cpu_address, data_l2);
    end else if (l1_missed && miss_l2) begin
      l2_miss_count <= l2_miss_count + 1;
      l2_missed <= 1;
      
      // Access main memory and promote to both caches
      mem_access_count <= mem_access_count + 1;
      
      // Promote to L2 first
      promote_l2_data <= 1;
      promotion_l2_data <= data_mem;
      $display("Promoting data from Memory to L2: Address=%h, Data=%h", cpu_address, data_mem);
      
      // Then promote to L1
      promote_l1_data <= 1;
      promotion_l1_data <= data_mem;
      $display("Promoting data from Memory to L1 & L2: Address=%h, Data=%h", cpu_address, data_mem);
    end
    
    if (l1_missed || l2_missed) begin
      $display("Access Complete: Address=%h", cpu_address);
      
      // Calculate and display hit rates and AMAT
      if (l1_hit_count + l1_miss_count > 0) begin
        $display("Performance Metrics:");
        $display("L1 Hits: %d, L1 Misses: %d", l1_hit_count, l1_miss_count);
        $display("L2 Hits: %d, L2 Misses: %d", l2_hit_count, l2_miss_count);
        
        // Calculate and display hit rates
        if (l1_hit_count + l1_miss_count > 0) begin
          $display("L1 Hit Rate: %.2f%%", (l1_hit_count * 100.0) / (l1_hit_count + l1_miss_count));
        end
        
        if (l1_miss_count > 0) begin
          $display("L2 Hit Rate: %.2f%%", (l2_hit_count * 100.0) / l1_miss_count);
        end
        
        // Calculate and display AMAT
        if (l1_miss_count > 0) begin
          $display("AMAT: %.2f cycles", 1.0 + (l1_miss_count * 1.0 / (l1_hit_count + l1_miss_count)) * 
                  (10.0 + (l2_miss_count * 1.0 / l1_miss_count) * 100.0));
        end
      end
    end
  end
endmodule
