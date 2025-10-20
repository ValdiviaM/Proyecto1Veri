class Scoreboard;
    mailbox #(pkt6) expected_mbx;
    mailbox #(pkt4) actual_mbx;
    test_sync sync; 
    // FIX: A functional scoreboard needs to queue expected items and compare them against actual items.
    protected pkt4 expected_q[$];
    protected int passed_transactions = 0;
    protected int failed_transactions = 0;
      
    protected bit all_expected_received = 0;
    protected int total_expected_count = 0;
    protected int received_actual_count = 0;

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
          check_completion(); // Check if the test is already done
          break; // Exit this loop
        end
        $display("[SCB] Received expected packet ID %0d with %0d words.", expected_pkt.id, expected_pkt.data.size());
        // Unpack the expected packet into individual transaction words for comparison.
        foreach(expected_pkt.data[i]) begin
          pkt4 expected_word = new();
          expected_word.data   = expected_pkt.data[i];
          expected_word.size   = expected_pkt.size[i];
          expected_word.offset = expected_pkt.offset[i];
          expected_q.push_back(expected_word);
          total_expected_count++;
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

        $display("[SCB] Received actual transaction from monitor (%0d of %0d).", received_actual_count, total_expected_count);

        if (expected_q.size() == 0) begin
          $error("[SCB] Received an actual transaction when none was expected. MISMATCH!");
          failed_transactions++;
          check_completion(); 
          continue;
        end

        // Compare the actual packet with the front of the expected queue.
        expected_word_to_compare = expected_q.pop_front();
        if (actual_pkt.size != expected_word_to_compare.size || actual_pkt.offset != expected_word_to_compare.offset) begin
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

          // align to LSB then mask
          actual_aligned   = (actual_pkt.data >> shift_actual) & cmp_mask;
          expected_aligned = (expected_word_to_compare.data >> shift_expected) & cmp_mask;

          data_match = (actual_aligned == expected_aligned);
          is_match = data_match;
        end
        
        if (is_match) begin
          $display("[SCB] Transaction MATCHED!");
          passed_transactions++;
        end else begin
          $error("[SCB] Transaction MISMATCH!");
          $display("  Expected: data=0x%h, size=%d, offset=%d", expected_word_to_compare.data, expected_word_to_compare.size, expected_word_to_compare.offset);
          $display("  Actual:   data=0x%h, size=%d, offset=%d", actual_pkt.data, actual_pkt.size, actual_pkt.offset);
          failed_transactions++;
        end
        check_completion();
      end
    endtask
    task check_completion();
    // The test is done ONLY when we've received the signal from the generator
    // AND the number of actual transactions matches the total we counted.
      if (all_expected_received && (received_actual_count == total_expected_count)) begin
        $display("[SCB] All expected transactions have been received. Test is done.");
        ->sync.test_done;
      end
    endtask
    function void report();
      $display("--- Scoreboard Report ---");
      $display("  Passed Transactions: %0d", passed_transactions);
      $display("  Failed Transactions: %0d", failed_transactions);
      if (expected_q.size() > 0) begin
          $error("[SCB] %0d expected transactions were never received by the scoreboard.", expected_q.size());
      end
      $display("-------------------------");
    endfunction
  endclass