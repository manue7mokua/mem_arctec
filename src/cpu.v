`timescale 1ns / 1ps

module cpu(
  input clk,
  input request_ready,
  output reg [10:0] address,
  output reg is_write,
  output reg [31:0] write_data,
  output reg request_valid,
  output reg trace_done
);
  parameter MAX_TRACE_SIZE = 10000;
  reg [10:0] trace_mem[0:MAX_TRACE_SIZE-1];
  reg trace_write[0:MAX_TRACE_SIZE-1];
  reg [31:0] trace_data[0:MAX_TRACE_SIZE-1];
  integer i = 0;
  integer trace_size = 0;
  integer file, status, line_count;
  reg [10:0] addr_val;
  reg [31:0] data_val;
  reg [8*80-1:0] line;
  reg [8*8-1:0] op_token;
  reg [8*256-1:0] trace_path;
  reg loaded_request;
  reg verbose;

  // Output debug every 1000 cycles
  integer cycle_count = 0;
  
  initial begin
    verbose = $test$plusargs("VERBOSE");
    // Initialize memory array to avoid X values
    for (i = 0; i < MAX_TRACE_SIZE; i = i + 1) begin
      trace_mem[i] = 11'h0;
      trace_write[i] = 1'b0;
      trace_data[i] = 32'h0;
    end
    address = 11'h0;
    is_write = 1'b0;
    write_data = 32'h0;
    request_valid = 1'b0;
    trace_done = 1'b0;
    
    // Prefer an explicit +TRACE=<path>, then fall back to the project traces.
    file = 0;
    if ($value$plusargs("TRACE=%s", trace_path)) begin
      file = $fopen(trace_path, "r");
      if (file == 0)
        $fatal(1, "Could not open trace file: %s", trace_path);
    end

    if (file == 0)
      file = $fopen("test/large_trace.txt", "r");
    if (file == 0) begin
      file = $fopen("test/test_trace.txt", "r");
      if (file == 0) begin
        file = $fopen("large_trace.txt", "r");
        if (file == 0) begin
          file = $fopen("test_trace.txt", "r");
          if (file == 0)
            $fatal(1, "Could not open a memory trace file");
        end
      end
    end
    
    line_count = 0;
    
    // Read the trace file line by line
    while (!$feof(file) && line_count < MAX_TRACE_SIZE) begin
      status = $fgets(line, file);
      
      if (status != 0) begin
        loaded_request = 1'b0;
        // Addresses are byte addresses. The cache hierarchy uses bits [1:0]
        // to select the containing 32-bit word for unaligned trace entries.
        data_val = 0;
        status = $sscanf(line, "%s %h %h", op_token, addr_val, data_val);
        if (status == 1) begin
          status = $sscanf(line, "%h", addr_val);
          if (status == 1) begin
            trace_mem[line_count] = addr_val;
            trace_write[line_count] = 1'b0;
            trace_data[line_count] = 32'h0;
            loaded_request = 1'b1;
          end
        end else if (status >= 2) begin
          if (op_token == "R" || op_token == "r") begin
            trace_mem[line_count] = addr_val;
            trace_write[line_count] = 1'b0;
            trace_data[line_count] = 32'h0;
            loaded_request = 1'b1;
          end else if (op_token == "W" || op_token == "w") begin
            trace_mem[line_count] = addr_val;
            trace_write[line_count] = 1'b1;
            trace_data[line_count] = (status == 3) ? data_val :
                                     (32'ha5000000 | addr_val);
            loaded_request = 1'b1;
          end
        end

        if (loaded_request) begin
          if (verbose && line_count < 20) begin
            $display("Loaded trace request[%0d]: %s %h", line_count, trace_write[line_count] ? "W" : "R", trace_mem[line_count]);
          end
          line_count = line_count + 1;
          if (verbose && line_count % 1000 == 0) begin
            $display("Loaded %0d addresses from trace file", line_count);
          end
        end
      end
    end
    
    $fclose(file);
    trace_size = line_count;
    $display("Loaded total of %0d addresses from trace file", trace_size);
    
    // Print the first 20 addresses from the array to verify loading
    if (verbose) begin
      $display("First 20 addresses in memory:");
      for (i = 0; i < 20 && i < trace_size; i = i + 1)
        $display("trace_mem[%0d] = %s %h", i,
                 trace_write[i] ? "W" : "R", trace_mem[i]);
    end
    
    i = 0;
    if (trace_size > 0) begin
      address = trace_mem[0];
      is_write = trace_write[0];
      write_data = trace_data[0];
      request_valid = 1'b1;
    end else begin
      trace_done = 1'b1;
    end
  end

  always @(posedge clk) begin
    cycle_count = cycle_count + 1;
    
    if (request_valid && request_ready) begin
      // Debug output for key addresses only
      if (verbose && (cycle_count % 1000 == 0 || i < 20)) begin
        $display("CPU emitting request[%0d] = %s %h", i, trace_write[i] ? "W" : "R", trace_mem[i]);
      end

      if (i + 1 < trace_size) begin
        i <= i + 1;
        address <= trace_mem[i + 1];
        is_write <= trace_write[i + 1];
        write_data <= trace_data[i + 1];
      end else begin
        request_valid <= 1'b0;
        trace_done <= 1'b1;
        $display("CPU completed trace after %0d requests", trace_size);
      end
    end
  end
endmodule
