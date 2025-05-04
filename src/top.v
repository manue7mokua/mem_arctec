module top(input clk, output [10:0] address, output hit_l1, output hit_l2, output [31:0] performance_counter_l1_hit, output [31:0] performance_counter_l1_miss, output [31:0] performance_counter_l2_hit, output [31:0] performance_counter_l2_miss);

  wire [10:0] cpu_address;
  wire [31:0] data_l1, data_l2, data_mem;
  wire miss_l1, miss_l2;
  
  reg [31:0] l1_hit_count = 0;
  reg [31:0] l1_miss_count = 0;
  reg [31:0] l2_hit_count = 0;
  reg [31:0] l2_miss_count = 0;
  reg [31:0] mem_access_count = 0;
  
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
    .data_out(data_l1)
  );

  l2_cache L2 (
    .clk(clk),
    .address(cpu_address),
    .l1_miss(miss_l1),
    .hit(hit_l2),
    .miss(miss_l2),
    .data_out(data_l2)
  );

  main_memory MEM (
    .clk(clk),
    .address(cpu_address),
    .l2_miss(miss_l2),
    .data_out(data_mem)
  );

  // Performance counters
  always @(posedge clk) begin
    if (hit_l1)
      l1_hit_count <= l1_hit_count + 1;
    if (miss_l1)
      l1_miss_count <= l1_miss_count + 1;
    if (hit_l2)
      l2_hit_count <= l2_hit_count + 1;
    if (miss_l2)
      l2_miss_count <= l2_miss_count + 1;
      
    // Calculate AMAT whenever we have a complete access cycle
    if (hit_l1 || (miss_l1 && hit_l2) || (miss_l1 && miss_l2)) begin
      $display("Access Complete: Address=%h", cpu_address);
      $display("Performance Metrics:");
      $display("L1 Hits: %d, L1 Misses: %d", l1_hit_count, l1_miss_count);
      $display("L2 Hits: %d, L2 Misses: %d", l2_hit_count, l2_miss_count);
      
      if (l1_hit_count + l1_miss_count > 0) begin
        // Use integer division and conversion to avoid real type
        $display("L1 Hit Rate: %.2f, L2 Hit Rate: %.2f", 
          (l1_hit_count * 100) / (l1_hit_count + l1_miss_count) / 100.0, 
          (l2_hit_count > 0) ? (l2_hit_count * 100) / l1_miss_count / 100.0 : 0);
          
        // Calculate AMAT using integer math as much as possible
        $display("AMAT: %.2f cycles", 
          1.0 + ((l1_miss_count * (10 + ((l1_miss_count - l2_hit_count) * 100) / 
          ((l1_miss_count > 0) ? l1_miss_count : 1))) / 
          ((l1_hit_count + l1_miss_count > 0) ? (l1_hit_count + l1_miss_count) : 1)));
      end
    end
  end

endmodule
