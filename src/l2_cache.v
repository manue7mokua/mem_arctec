module l2_cache #(
  parameter CACHE_SIZE = 512,
  parameter BLOCK_SIZE = 32,
  parameter MAPPING_TYPE = 0,
  parameter REPLACEMENT_POLICY = 0
)(
  input clk,
  input [10:0] lookup_address,
  input lookup_is_write,
  input [31:0] lookup_write_data,
  input access_enable,
  output hit,
  output miss,
  output [31:0] data_out,
  input fill_enable,
  input [10:0] fill_address,
  input [31:0] fill_data,
  input fill_dirty,
  output eviction_valid,
  output eviction_dirty,
  output [10:0] eviction_address,
  output [31:0] eviction_data
);
  cache_level #(
    .CACHE_SIZE(CACHE_SIZE),
    .BLOCK_SIZE(BLOCK_SIZE),
    .MAPPING_TYPE(MAPPING_TYPE),
    .REPLACEMENT_POLICY(REPLACEMENT_POLICY),
    .RANDOM_SEED(32'h5e6f7788)
  ) storage (
    .clk(clk),
    .lookup_address(lookup_address),
    .lookup_is_write(lookup_is_write),
    .lookup_write_data(lookup_write_data),
    .access_enable(access_enable),
    .hit(hit),
    .miss(miss),
    .data_out(data_out),
    .fill_enable(fill_enable),
    .fill_address(fill_address),
    .fill_data(fill_data),
    .fill_dirty(fill_dirty),
    .eviction_valid(eviction_valid),
    .eviction_dirty(eviction_dirty),
    .eviction_address(eviction_address),
    .eviction_data(eviction_data)
  );
endmodule
