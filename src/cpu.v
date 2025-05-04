module cpu(input clk, output reg [10:0] address);
  // We have 135 addresses in our trace file
  reg [10:0] trace_mem[0:134];
  integer i = 0;

  initial begin
    $readmemh("test/test_trace.txt", trace_mem);
  end

  always @(posedge clk) begin
    address <= trace_mem[i];
    i <= i + 1;
    
    // Reset index when at the end
    if (i >= 134)
      i <= 0;
  end
endmodule
