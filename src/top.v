module top(input clk, output [10:0] address, output hit_l1, output hit_l2, output [31:0] performance_counter_l1_hit, output [31:0] performance_counter_l1_miss, output [31:0] performance_counter_l2_hit, output [31:0] performance_counter_l2_miss);

  // Use a simpler include path that will work with the -I flag
  `include "src/cache_config.v"

  wire [10:0] cpu_address;
  wire [31:0] data_l1, data_l2, data_mem;
  wire miss_l1, miss_l2;
  
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
  reg last_miss_l1, last_miss_l2;
  reg last_hit_l1, last_hit_l2;
  
  assign address = cpu_address;
  assign performance_counter_l1_hit = l1_hit_count;
  assign performance_counter_l1_miss = l1_miss_count;
  assign performance_counter_l2_hit = l2_hit_count;
  assign performance_counter_l2_miss = l2_miss_count;

  cpu CPU (
    .clk(clk),
    .address(cpu_address)
  );

  l1_cache L1 (
    .clk(clk),
    .address(cpu_address),
    .hit(hit_l1),
    .miss(miss_l1),
    .data_out(data_l1),
    .promote_data(promote_l1_data),
    .promotion_data(promotion_l1_data)
  );

  l2_cache L2 (
    .clk(clk),
    .address(cpu_address),
    .l1_miss(miss_l1),
    .hit(hit_l2),
    .miss(miss_l2),
    .data_out(data_l2),
    .promote_data(promote_l2_data),
    .promotion_data(promotion_l2_data)
  );

  main_memory MEM (
    .clk(clk),
    .address(cpu_address),
    .l2_miss(miss_l2),
    .data_out(data_mem)
  );

  // Store the state from the previous cycle
  always @(posedge clk) begin
    last_address <= cpu_address;
    last_miss_l1 <= miss_l1;
    last_miss_l2 <= miss_l2;
    last_hit_l1 <= hit_l1;
    last_hit_l2 <= hit_l2;
  end

  // Promotion logic - now properly synchronized with hit/miss signals
  always @(posedge clk) begin
    // Default reset promotion signals to avoid continuous promotion
    promote_l1_data <= 0;
    promote_l2_data <= 0;
    
    // When L1 miss but L2 hit, promote data from L2 to L1
    if (miss_l1 && hit_l2) begin
      promote_l1_data <= 1;
      promotion_l1_data <= data_l2;
      $display("Promoting data from L2 to L1: Address=%h, Data=%h", cpu_address, data_l2);
    end 
    // When both L1 and L2 miss, promote data from memory to both L1 and L2
    else if (miss_l1 && miss_l2) begin
      promote_l1_data <= 1;
      promotion_l1_data <= data_mem;
      promote_l2_data <= 1;
      promotion_l2_data <= data_mem;
      $display("Promoting data from Memory to L1 & L2: Address=%h, Data=%h", cpu_address, data_mem);
    end
  end

  // Performance counters with improved logic to avoid race conditions
  always @(posedge clk) begin
    // Count hit/miss for the previous access which has been fully resolved by now
    if (hit_l1)
      l1_hit_count <= l1_hit_count + 1;
    if (miss_l1)
      l1_miss_count <= l1_miss_count + 1;
    if (miss_l1 && hit_l2)
      l2_hit_count <= l2_hit_count + 1;
    if (miss_l1 && miss_l2)
      l2_miss_count <= l2_miss_count + 1;
      
    // Display access completion and performance metrics
    if (hit_l1 || (miss_l1 && hit_l2) || (miss_l1 && miss_l2)) begin
      $display("Access Complete: Address=%h", cpu_address);
      $display("Performance Metrics:");
      $display("L1 Hits: %d, L1 Misses: %d", l1_hit_count, l1_miss_count);
      $display("L2 Hits: %d, L2 Misses: %d", l2_hit_count, l2_miss_count);
      
      if (l1_hit_count + l1_miss_count > 0) begin
        // Use integer division and conversion to avoid real type
        $display("L1 Hit Rate: %.2f%%, L2 Hit Rate: %.2f%%", 
          (l1_hit_count * 100.0) / (l1_hit_count + l1_miss_count), 
          (l2_hit_count > 0 && l1_miss_count > 0) ? (l2_hit_count * 100.0) / l1_miss_count : 0);
          
        // Calculate AMAT using integer math as much as possible to avoid real type issues
        $display("AMAT: %.2f cycles", 
          1.0 + ((l1_miss_count * 1.0) / (l1_hit_count + l1_miss_count)) * 
          (10.0 + ((l2_miss_count * 1.0) / (l1_miss_count > 0 ? l1_miss_count : 1)) * 100.0));
      end
    end
  end

endmodule
