


class Checker;
  // Configuration
  int ALGN_DATA_WIDTH;
  int FIFO_DEPTH;
  
  // Counters
  int error_count;
  int warning_count;
  int checks_performed;
  
  // Statistics
  int alignment_config_checks;
  int data_transfer_checks;
  
  // Control
  bit enable_checking;

  function new(int data_width = 32, int fifo_depth = 8);
    this.ALGN_DATA_WIDTH = data_width;
    this.FIFO_DEPTH = fifo_depth;
    this.error_count = 0;
    this.warning_count = 0;
    this.enable_checking = 1;
    this.checks_performed = 0;
    this.alignment_config_checks = 0;
    this.data_transfer_checks = 0;
  endfunction

  function void reset_stats();
    error_count = 0;
    warning_count = 0;
    checks_performed = 0;
    alignment_config_checks = 0;
    data_transfer_checks = 0;
  endfunction

  // Check if alignment configuration is legal
  function bit check_alignment_config(bit [2:0] size, bit [1:0] offset);
    bit pass = 1;
    alignment_config_checks++;
    checks_performed++;
    
    if (!enable_checking) return pass;
    
    // Size must be 1, 2, or 4 bytes
    if (size != 1 && size != 2 && size != 4) begin
      $error("[CHECKER] Illegal SIZE=%0d (must be 1, 2, or 4)", size);
      error_count++;
      pass = 0;
    end
    
    // Check legal size/offset combinations
    case (size)
      1: begin
        // 1-byte transfers: offset can be 0, 1, 2, 3 (any)
        if (offset > 3) begin
          $error("[CHECKER] OFFSET=%0d out of range for SIZE=1", offset);
          error_count++;
          pass = 0;
        end
      end
      2: begin
        // 2-byte transfers: offset must be even (0 or 2)
        if (offset % 2 != 0) begin
          $error("[CHECKER] Illegal alignment: SIZE=2 requires even OFFSET, got OFFSET=%0d", offset);
          error_count++;
          pass = 0;
        end
      end
      4: begin
        // 4-byte transfers: offset must be 0
        if (offset != 0) begin
          $error("[CHECKER] Illegal alignment: SIZE=4 requires OFFSET=0, got OFFSET=%0d", offset);
          error_count++;
          pass = 0;
        end
      end
    endcase
    
    if (pass) begin
      $display("[CHECKER] Valid alignment config: SIZE=%0d, OFFSET=%0d", size, offset);
    end
    
    return pass;
  endfunction

  // Check if a data transfer matches expected alignment rules
  function bit check_transfer_alignment(bit [31:0] data, bit [2:0] size, bit [1:0] offset,
                                        bit [2:0] expected_size, bit [1:0] expected_offset);
    bit pass = 1;
    data_transfer_checks++;
    checks_performed++;
    
    if (!enable_checking) return pass;
    
    // Check size matches configuration
    if (size != expected_size) begin
      $error("[CHECKER] Transfer SIZE mismatch: got %0d, expected %0d", size, expected_size);
      error_count++;
      pass = 0;
    end
    
    // Check offset matches configuration
    if (offset != expected_offset) begin
      $error("[CHECKER] Transfer OFFSET mismatch: got %0d, expected %0d", offset, expected_offset);
      error_count++;
      pass = 0;
    end
    
    // Verify data is properly aligned within the word
    if (pass) begin
      bit [31:0] mask;
      bit [31:0] masked_data;
      int byte_shift = offset * 8;
      
      case (size)
        1: mask = 32'hFF;
        2: mask = 32'hFFFF;
        4: mask = 32'hFFFF_FFFF;
        default: mask = 32'h0;
      endcase
      
      // Check that data outside the transfer size/offset is zero
      masked_data = (data >> byte_shift) & mask;
      if ((masked_data << byte_shift) != data && size < 4) begin
        $warning("[CHECKER] Data has non-zero bits outside transfer region: data=0x%08h, size=%0d, offset=%0d",
                 data, size, offset);
        warning_count++;
      end
    end
    
    return pass;
  endfunction

  // Check data alignment extraction is correct
  function bit check_data_extraction(bit [31:0] input_data, bit [2:0] input_size, bit [1:0] input_offset,
                                      bit [31:0] output_data, bit [2:0] output_size, bit [1:0] output_offset);
    bit pass = 1;
    bit [31:0] expected_output;
    bit [31:0] mask;
    int shift_bits;
    
    checks_performed++;
    
    if (!enable_checking) return pass;
    
    // Calculate expected output by extracting from input
    shift_bits = input_offset * 8;
    
    case (input_size)
      1: mask = 32'hFF;
      2: mask = 32'hFFFF;
      4: mask = 32'hFFFF_FFFF;
      default: mask = 32'h0;
    endcase
    
    expected_output = (input_data >> shift_bits) & mask;
    
    // Now shift to output position
    shift_bits = output_offset * 8;
    expected_output = expected_output << shift_bits;
    
    if (output_data != expected_output) begin
      $error("[CHECKER] Data extraction mismatch:");
      $error("         Input:  data=0x%08h, size=%0d, offset=%0d", input_data, input_size, input_offset);
      $error("         Output: data=0x%08h, size=%0d, offset=%0d", output_data, output_size, output_offset);
      $error("         Expected output: 0x%08h", expected_output);
      error_count++;
      pass = 0;
    end
    
    return pass;
  endfunction

  // Check that size/offset combinations are legal
  function bit is_legal_combination(bit [2:0] size, bit [1:0] offset);
    case (size)
      1: return (offset <= 3);
      2: return (offset % 2 == 0);
      4: return (offset == 0);
      default: return 0;
    endcase
  endfunction

  // Validate a complete transaction
  function bit validate_transaction(bit [31:0] input_data, bit [2:0] input_size, bit [1:0] input_offset,
                                    bit [31:0] output_data, bit [2:0] output_size, bit [1:0] output_offset,
                                    bit [2:0] config_size, bit [1:0] config_offset);
    bit pass = 1;
    checks_performed++;
    
    if (!enable_checking) return pass;
    
    // Check if input transfer is legal
    if (!is_legal_combination(input_size, input_offset)) begin
      $error("[CHECKER] Illegal input transfer: size=%0d, offset=%0d", input_size, input_offset);
      error_count++;
      pass = 0;
    end
    
    // Check if output transfer matches configuration
    if (output_size != config_size || output_offset != config_offset) begin
      $error("[CHECKER] Output doesn't match config: output(size=%0d,offset=%0d) vs config(size=%0d,offset=%0d)",
             output_size, output_offset, config_size, config_offset);
      error_count++;
      pass = 0;
    end
    
    // Check if input matches configuration (for legal transfers)
    if (input_size == config_size && input_offset == config_offset) begin
      // This is a legal transfer, should be passed through
      if (!check_data_extraction(input_data, input_size, input_offset,
                                  output_data, output_size, output_offset)) begin
        pass = 0;
      end
    end else begin
      // This is an illegal transfer, should be dropped
      $display("[CHECKER] Transfer dropped (size/offset mismatch with config)");
    end
    
    return pass;
  endfunction

  // Report final statistics
  function void report(string prefix = "");
    $display("========================================");
    $display("%s ALIGNER CHECKER REPORT", prefix);
    $display("========================================");
    $display("Total checks performed:   %0d", checks_performed);
    $display("  Alignment configs:      %0d", alignment_config_checks);
    $display("  Data transfers:         %0d", data_transfer_checks);
    $display("----------------------------------------");
    $display("Errors found:             %0d", error_count);
    $display("Warnings:                 %0d", warning_count);
    $display("========================================");
    
    if (error_count == 0) begin
      $display("%s *** ALL CHECKER VALIDATIONS PASSED! ***", prefix);
    end else begin
      $display("%s *** CHECKER FOUND %0d ERRORS ***", prefix, error_count);
    end
    $display("========================================");
  endfunction

  // Helper functions
  function bit all_checks_passed();
    return (error_count == 0);
  endfunction
  
  function int get_error_count();
    return error_count;
  endfunction
  
  function int get_warning_count();
    return warning_count;
  endfunction
  
  function void set_enable(bit enable);
    enable_checking = enable;
  endfunction

endclass
