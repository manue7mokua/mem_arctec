module cpu(input clk, output reg [10:0] address);
  parameter MAX_TRACE_SIZE = 10000;
  reg [10:0] trace_mem[0:MAX_TRACE_SIZE-1];
  integer i = 0;
  integer trace_size = 0;
  integer file, status, line_count;
  reg [10:0] addr_val;
  reg [8*80-1:0] line;

  // Output debug every 1000 cycles
  integer cycle_count = 0;
  
  initial begin
    // Initialize memory array to avoid X values
    for (i = 0; i < MAX_TRACE_SIZE; i = i + 1) begin
      trace_mem[i] = 11'h0;
    end
    
    // Read the trace file - make sure path is relative to where the simulation runs
    file = $fopen("test/large_trace.txt", "r");
    if (file == 0) begin
      $display("Error: Could not open large trace file at test/large_trace.txt");
      // Try an alternative path
      file = $fopen("large_trace.txt", "r");
      if (file == 0) begin
        $display("Error: Could not open large trace file at large_trace.txt either");
        $finish;
      end
    end
    
    line_count = 0;
    
    // Read the trace file line by line
    while (!$feof(file) && line_count < MAX_TRACE_SIZE) begin
      status = $fgets(line, file);
      
      // Check if valid line (we expect hex numbers directly)
      if (status != 0) begin
        // Parse the hex value directly
        status = $sscanf(line, "%h", addr_val);
        if (status == 1) begin
          trace_mem[line_count] = addr_val;
          // Debug output for first 20 addresses
          if (line_count < 20) begin
            $display("Loaded trace address[%0d]: %h", line_count, addr_val);
          end
          line_count = line_count + 1;
          if (line_count % 1000 == 0) begin
            $display("Loaded %0d addresses from trace file", line_count);
          end
        end
      end
    end
    
    $fclose(file);
    trace_size = line_count;
    $display("Loaded total of %0d addresses from trace file", trace_size);
    
    // Print the first 20 addresses from the array to verify loading
    $display("First 20 addresses in memory:");
    for (i = 0; i < 20 && i < trace_size; i = i + 1) begin
      $display("trace_mem[%0d] = %h", i, trace_mem[i]);
    end
    
    i = 0;
  end

  always @(posedge clk) begin
    cycle_count = cycle_count + 1;
    
    if (i < trace_size) begin
      address <= trace_mem[i];
      
      // Debug output for key addresses only
      if (cycle_count % 1000 == 0 || i < 20) begin
        $display("CPU emitting address[%0d] = %h", i, trace_mem[i]);
      end
      
      i <= i + 1;
    end else begin
      if (trace_size == 0) begin
        // No addresses loaded, use a default
        address <= 11'h0;
        $display("Warning: No addresses loaded from trace file, using default address 000");
      end else begin
        // Reset to the beginning of the trace
        i <= 0;
        address <= trace_mem[0];
        $display("CPU reset to address[0] = %h", trace_mem[0]);
      end
    end
  end
endmodule
