module l2_cache #(
  parameter CACHE_SIZE = 512,
  parameter BLOCK_SIZE = 32,
  parameter MAPPING_TYPE = 0,
  parameter REPLACEMENT_POLICY = 0,
  parameter LINE_WIDTH = BLOCK_SIZE * 8
)(
  input clk,
  input [10:0] lookup_address,
  input lookup_is_write,
  input [31:0] lookup_write_data,
  input lookup_line_write_enable,
  input [LINE_WIDTH-1:0] lookup_line_write_data,
  input access_enable,
  output hit,
  output miss,
  output [31:0] data_out,
  output [LINE_WIDTH-1:0] line_out,
  input fill_enable,
  input [10:0] fill_address,
  input [LINE_WIDTH-1:0] fill_line,
  input fill_dirty,
  output eviction_valid,
  output eviction_dirty,
  output [10:0] eviction_address,
  output [LINE_WIDTH-1:0] eviction_line
);
  cache_level #(
    .CACHE_SIZE(CACHE_SIZE),
    .BLOCK_SIZE(BLOCK_SIZE),
    .MAPPING_TYPE(MAPPING_TYPE),
    .REPLACEMENT_POLICY(REPLACEMENT_POLICY),
    .RANDOM_SEED(32'h5e6f7788),
    .LINE_WIDTH(LINE_WIDTH)
  ) storage (
    .clk(clk),
    .lookup_address(lookup_address),
    .lookup_is_write(lookup_is_write),
    .lookup_write_data(lookup_write_data),
    .lookup_line_write_enable(lookup_line_write_enable),
    .lookup_line_write_data(lookup_line_write_data),
    .access_enable(access_enable),
    .hit(hit),
    .miss(miss),
    .data_out(data_out),
    .line_out(line_out),
    .fill_enable(fill_enable),
    .fill_address(fill_address),
    .fill_line(fill_line),
    .fill_dirty(fill_dirty),
    .eviction_valid(eviction_valid),
    .eviction_dirty(eviction_dirty),
    .eviction_address(eviction_address),
    .eviction_line(eviction_line)
  );
endmodule
