module l1_cache(input clk, input [10:0] address, output reg hit, output reg miss, output reg [31:0] data_out);
  parameter CACHE_SIZE = 256;
  parameter BLOCK_SIZE = 16;
  parameter NUM_BLOCKS = CACHE_SIZE / BLOCK_SIZE;

  reg valid[NUM_BLOCKS-1:0];
  reg [6:0] tags[NUM_BLOCKS-1:0];
  reg [31:0] data[NUM_BLOCKS-1:0];
  
  // For a direct-mapped cache with 16 blocks:
  // Block offset: 4 bits (log2(16) = 4)
  // Index: 4 bits (2^4 = 16 blocks)
  // Tag: 3 bits (11 - 4 - 4 = 3 bits from the address)
  wire [3:0] block_offset = address[3:0];
  wire [3:0] index = address[7:4];
  wire [2:0] tag = address[10:8];

  integer i;
  
  initial begin
    for (i = 0; i < NUM_BLOCKS; i = i + 1) begin
      valid[i] = 0;
    end
  end

  always @(posedge clk) begin
    if (valid[index] && tags[index] == tag) begin
      hit <= 1;
      miss <= 0;
      data_out <= data[index];
      $display("L1 Cache HIT: Address=%h, Index=%h, Tag=%h", address, index, tag);
    end else begin
      hit <= 0;
      miss <= 1;
      data_out <= 0;
      $display("L1 Cache MISS: Address=%h, Index=%h, Tag=%h", address, index, tag);
      // On a miss, we update the cache with data that would come from L2 or memory
      // In this simulation, we'll just mark it as valid and update the tag
      valid[index] <= 1;
      tags[index] <= tag;
      data[index] <= 32'hDEADBEEF; // Placeholder data
    end
  end
endmodule
