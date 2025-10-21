
  
  
  class Scoreboard;
    mailbox #(pkt6) expected_mbx;
    mailbox #(pkt4) actual_mbx;
    test_sync sync; 
    
    protected pkt4 expected_q[$];
    protected int passed_transactions = 0;
    protected int failed_transactions = 0;
      
    protected bit all_expected_received = 0;
    protected int total_expected_count = 0;
    protected int received_actual_count = 0;
    protected int comparison_count = 0;

    function new(mailbox #(pkt6) expected_mbx, mailbox #(pkt4) actual_mbx, test_sync sync);
      this.expected_mbx = expected_mbx;
      this.actual_mbx = actual_mbx;
      this.sync = sync;
    endfunction

    task run();
      fork
        receive_expected();
        receive_actual();
      join_none
    endtask
    
    task receive_expected();
      pkt6 expected_pkt;
      forever begin
        expected_mbx.get(expected_pkt);

        if (expected_pkt.is_last) begin
          $display("[SCB] Received final expected packet. Total expected words: %0d.", total_expected_count);
          all_expected_received = 1;
          check_completion();
          break;
        end
        
        $display("[SCB] Received expected packet ID %0d with %0d words.", expected_pkt.id, expected_pkt.data.size());
        
        foreach(expected_pkt.data[i]) begin
          pkt4 expected_word = new();
          expected_word.data   = expected_pkt.data[i];
          expected_word.size   = expected_pkt.size[i];
          expected_word.offset = expected_pkt.offset[i];
          expected_q.push_back(expected_word);
          total_expected_count++;
          $display("[SCB] Queued expected word %0d: data=0x%08h, size=%0d, offset=%0d", 
                   total_expected_count, expected_word.data, expected_word.size, expected_word.offset);
        end
      end
    endtask

    task receive_actual();
      pkt4 actual_pkt;
      forever begin        
        pkt4 expected_word_to_compare;
        bit is_match;
        
        actual_mbx.get(actual_pkt);
        received_actual_count++;

        $display("[SCB] Received actual transaction #%0d: data=0x%08h, size=%0d, offset=%0d", 
                 received_actual_count, actual_pkt.data, actual_pkt.size, actual_pkt.offset);

        // Wait briefly if expected queue is empty but we haven't received all expected yet
        if (expected_q.size() == 0 && !all_expected_received) begin
          $display("[SCB] Waiting for expected transaction to arrive...");
          repeat(10) #1ns;
        end

        if (expected_q.size() == 0) begin
          $error("[SCB] Received actual transaction #%0d when none was expected. MISMATCH!", received_actual_count);
          $display("       Actual: data=0x%08h, size=%0d, offset=%0d", 
                   actual_pkt.data, actual_pkt.size, actual_pkt.offset);
          failed_transactions++;
          comparison_count++;
          check_completion(); 
          continue;
        end

        expected_word_to_compare = expected_q.pop_front();
        comparison_count++;
        
        // Compare size and offset first
        if (actual_pkt.size != expected_word_to_compare.size || 
            actual_pkt.offset != expected_word_to_compare.offset) begin
          is_match = 1'b0;
        end else begin
          bit data_match;
          bit [31:0] actual_aligned, expected_aligned;
          bit [31:0] cmp_mask;
          int shift_actual, shift_expected;

          case (actual_pkt.size)
            1: cmp_mask = 32'hFF;
            2: cmp_mask = 32'hFFFF;
            4: cmp_mask = 32'hFFFF_FFFF;
            default: cmp_mask = 32'h0;
          endcase

          shift_actual   = actual_pkt.offset * 8;
          shift_expected = expected_word_to_compare.offset * 8;

          actual_aligned   = (actual_pkt.data >> shift_actual) & cmp_mask;
          expected_aligned = (expected_word_to_compare.data >> shift_expected) & cmp_mask;

          data_match = (actual_aligned == expected_aligned);
          is_match = data_match;
          
          if (!data_match) begin
            $display("[SCB] Data mismatch detail:");
            $display("       actual_aligned=0x%08h, expected_aligned=0x%08h", 
                     actual_aligned, expected_aligned);
            $display("       mask=0x%08h, shift_actual=%0d, shift_expected=%0d",
                     cmp_mask, shift_actual, shift_expected);
          end
        end
        
        if (is_match) begin
          $display("[SCB] Transaction #%0d MATCHED!", comparison_count);
          passed_transactions++;
        end else begin
          $error("[SCB] Transaction #%0d MISMATCH!", comparison_count);
          $display("  Expected: data=0x%08h, size=%0d, offset=%0d", 
                   expected_word_to_compare.data, expected_word_to_compare.size, expected_word_to_compare.offset);
          $display("  Actual:   data=0x%08h, size=%0d, offset=%0d", 
                   actual_pkt.data, actual_pkt.size, actual_pkt.offset);
          failed_transactions++;
        end
        
        check_completion();
      end
    endtask
    
    task check_completion();
      if (all_expected_received && (comparison_count >= total_expected_count)) begin
        $display("[SCB] Test completion conditions met:");
        $display("      - All expected received: %0d", all_expected_received);
        $display("      - Comparisons made: %0d / %0d expected", comparison_count, total_expected_count);
        $display("      - Expected queue size: %0d", expected_q.size());
        $display("      - Passed: %0d, Failed: %0d", passed_transactions, failed_transactions);
        ->sync.test_done;
      end
    endtask
    
    function void report();
      $display("========================================");
      $display("      Scoreboard Final Report");
      $display("========================================");
      $display("  Total Expected Words:     %0d", total_expected_count);
      $display("  Actual Received:          %0d", received_actual_count);
      $display("  Comparisons Made:         %0d", comparison_count);
      $display("  Passed Transactions:      %0d", passed_transactions);
      $display("  Failed Transactions:      %0d", failed_transactions);
      
      if (expected_q.size() > 0) begin
        $error("[SCB] %0d expected transactions were never matched!", expected_q.size());
        $display("     Unmatched expected transactions:");
        foreach(expected_q[i]) begin
          $display("       [%0d] data=0x%08h, size=%0d, offset=%0d", 
                   i, expected_q[i].data, expected_q[i].size, expected_q[i].offset);
        end
      end
      
      if (failed_transactions == 0 && comparison_count == total_expected_count) begin
        $display("\n  *** TEST PASSED ***");
      end else begin
        $display("\n  *** TEST FAILED ***");
      end
      $display("========================================");
    endfunction
  endclass
