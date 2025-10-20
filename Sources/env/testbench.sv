  // ===================================================================
  // 1. ALL PACKET DEFINITIONS FIRST
  // ===================================================================

  class test_sync;
    event test_done;
  endclass

  class pkt1;
    bit with_window;
    int num_pkts;
    int delay_min_ns;
    int delay_max_ns;

    function new();
      with_window  = 0;
      num_pkts     = 20;
      delay_min_ns = 1;
      delay_max_ns = 10;
    endfunction
  endclass

  class pkt_base;
    rand int unsigned inter_pkt_time_ns;
    constraint c_delay { inter_pkt_time_ns inside {[0:10000]}; }
  endclass

  class apb_pkt extends pkt_base;
    rand bit        write_en;
    rand bit [15:0] addr;
    rand bit [31:0] data;
  endclass

  class md_pkt extends pkt_base;
    rand int unsigned num_words = 1;
    rand bit [31:0] data[];
    rand bit [2:0]  size[];
    rand bit [1:0]  offset[];

    constraint c_sizes {
      num_words inside {[1:16]};
      data.size() == num_words;
      size.size() == num_words;
      offset.size() == num_words;
      foreach(size[i]) size[i] inside {3'd1, 3'd2, 3'd4};
    }

    constraint c_legal_combinations {
      foreach(data[i]) {
        (size[i] == 2) -> (offset[i] % 2 == 0);
        (size[i] == 4) -> (offset[i] == 0);
      }
    }
  endclass

  class pkt4;
    rand bit [31:0] data;
    rand bit [2:0]  size;
    rand bit [1:0]  offset;

    function new();
    endfunction
    
    // This function was empty and unused. It can be removed or implemented if needed later.
    function void set_aligment(bit[2:0] s, bit[1:0] o);
        this.size = s;
        this.offset = o;
    endfunction
  endclass
  class pkt6;
    int id;
    bit [31:0] data[$];
    bit [2:0]  size[$];
    bit [1:0]  offset[$];
    bit is_last; // <-- ADD THIS FLAG

    function new();
      id = 0;
      data = {};
      size = {};
      offset = {};
      is_last = 0; // Default to 0
    endfunction
  endclass


  // ===================================================================
  // 2. INTERFACE DEFINITIONS
  // ===================================================================

  interface apb_if #(parameter ADDR_WIDTH = 16, DATA_WIDTH = 32);
    logic pclk;
    logic reset_n;
    logic [ADDR_WIDTH-1:0] paddr;
    logic pwrite;
    logic psel;
    logic penable;
    logic [DATA_WIDTH-1:0] pwdata;
    logic pready;
    logic [DATA_WIDTH-1:0] prdata;
    logic pslverr;

    clocking master_cb @(posedge pclk);
      default input #1step output #0;
      output paddr, pwrite, psel, penable, pwdata;
      input  pready, prdata, pslverr;
    endclocking;

    modport DUT (
      input pclk, reset_n, paddr, pwrite, psel, penable, pwdata,
      output pready, prdata, pslverr
    );

    modport Transactor (
      clocking master_cb,
      input pclk,
      output reset_n
    );
  endinterface

  interface md_if #(parameter DATA_WIDTH = 32, OFFSET_WIDTH = 2, SIZE_WIDTH = 3);
    logic clk;
    logic reset_n;
    
    logic md_rx_valid;
    logic [DATA_WIDTH-1:0] md_rx_data;
    logic [OFFSET_WIDTH-1:0] md_rx_offset;
    logic [SIZE_WIDTH-1:0] md_rx_size;
    logic md_rx_ready;
    logic md_rx_err;

    logic md_tx_valid;
    logic [DATA_WIDTH-1:0] md_tx_data;
    logic [OFFSET_WIDTH-1:0] md_tx_offset;
    logic [SIZE_WIDTH-1:0] md_tx_size;
    logic md_tx_ready;
    logic md_tx_err;

    clocking transactor_cb @(posedge clk);
      default input #1step output #0;
      output md_rx_valid, md_rx_data, md_rx_offset, md_rx_size;
      input  md_rx_ready, md_rx_err;
      input  md_tx_valid, md_tx_data, md_tx_offset, md_tx_size;
      output md_tx_ready, md_tx_err;
    endclocking;

    modport DUT (
      input  clk, reset_n, md_rx_valid, md_rx_data, md_rx_offset, md_rx_size, md_tx_ready, md_tx_err,
      output md_rx_ready, md_rx_err, md_tx_valid, md_tx_data, md_tx_offset, md_tx_size
    );

    modport Transactor (
      clocking transactor_cb,
      input clk,
      output reset_n
    );
  endinterface


  // ===================================================================
  // 3. ALL TRANSACCTOR CLASS DEFINITIONS
  // ===================================================================

  class apb_driver;
    virtual apb_if.Transactor apb_vif;
    mailbox #(apb_pkt) drv_mbx;
    mailbox #(bit)          rsp_mbx;

    function new(virtual apb_if.Transactor apb_vif, 
                mailbox #(apb_pkt) drv_mbx, 
                mailbox #(bit) rsp_mbx);
      this.apb_vif = apb_vif;
      this.drv_mbx = drv_mbx;
      this.rsp_mbx = rsp_mbx; // <-- STORE IT
    endfunction

    task run();
      forever begin
        apb_pkt pkt;
        drv_mbx.get(pkt);
        drive_transaction(pkt);
      end
    endtask

    task drive_transaction(apb_pkt p);
      apb_vif.master_cb.psel   <= 1'b1;
      apb_vif.master_cb.paddr  <= p.addr;
      apb_vif.master_cb.pwrite <= p.write_en;
      apb_vif.master_cb.pwdata <= p.data;
      @(apb_vif.master_cb);
      apb_vif.master_cb.penable <= 1'b1;
      while (!apb_vif.master_cb.pready) @(apb_vif.master_cb);
      @(apb_vif.master_cb);
      apb_vif.master_cb.psel    <= 1'b0;
      apb_vif.master_cb.penable <= 1'b0;
      rsp_mbx.put(1'b1);
    endtask
  endclass

  class md_driver;
    virtual md_if.Transactor md_vif;
    mailbox #(md_pkt) drv_mbx;

    function new(virtual md_if.Transactor md_vif, mailbox #(md_pkt) drv_mbx);
      this.md_vif = md_vif;
      this.drv_mbx = drv_mbx;
    endfunction

    task run();
      fork
        run_tx_handler();
        run_rx_sender();
      join_none
    endtask

    task run_rx_sender();
      forever begin
        md_pkt pkt;
        drv_mbx.get(pkt);
        drive_transaction(pkt);
      end
    endtask

    task run_tx_handler();
      md_vif.transactor_cb.md_tx_ready <= 1'b1;
      md_vif.transactor_cb.md_tx_err   <= 1'b0;
      forever @(md_vif.transactor_cb);
    endtask

    task drive_transaction(md_pkt p);
      if (p.inter_pkt_time_ns > 0) begin
        md_vif.transactor_cb.md_rx_valid <= 1'b0;
        // FIX: Use the clocking block for all delays to avoid race conditions.
        // The clock period is 10ns, so divide by 10.


        repeat(p.inter_pkt_time_ns / 10) @(md_vif.transactor_cb);
      end

      foreach(p.data[i]) begin
        md_vif.transactor_cb.md_rx_valid  <= 1'b1;
        md_vif.transactor_cb.md_rx_data   <= p.data[i];
        md_vif.transactor_cb.md_rx_size   <= p.size[i];
        md_vif.transactor_cb.md_rx_offset <= p.offset[i];
        do @(md_vif.transactor_cb); while (!md_vif.transactor_cb.md_rx_ready);
        $display("[MD_DRV] driving md_rx_data=0x%08h size=%0d offset=%0d (wait for md_rx_ready)",
         p.data[i], p.size[i], p.offset[i]);
      end
      md_vif.transactor_cb.md_rx_valid <= 1'b0;
      @(md_vif.transactor_cb);
    endtask
  endclass

  class apb_monitor;
    virtual apb_if.Transactor apb_vif;
    mailbox #(pkt4) actual_mbx;
    pkt4 dut_state;

    localparam ADDR_CTRL   = 16'h00;
    localparam ADDR_IRQ_EN = 16'h08;

    function new(virtual apb_if.Transactor apb_vif, mailbox #(pkt4) actual_mbx, pkt4 dut_state);
      this.apb_vif = apb_vif;
      this.actual_mbx = actual_mbx;
      this.dut_state = dut_state;
    endfunction

  task run();
    forever begin
      @(apb_vif.master_cb);
      if (apb_vif.master_cb.psel && apb_vif.master_cb.penable && apb_vif.master_cb.pready) begin
        if (apb_vif.master_cb.pwrite) begin
          // FIX: This monitor should observe the bus, but not send packets to the scoreboard.
          // The line below has been removed.
          // actual_mbx.put(dut_state);
          
          // Optionally, you could add a display here for debugging purposes.
          $display("[APB_MON] Detected APB write to addr %h with data %h", 
                  apb_vif.master_cb.paddr, apb_vif.master_cb.pwdata);
        end
      end
    end
  endtask
  endclass

  class md_monitor;
    virtual md_if.Transactor md_vif;
    mailbox #(pkt4) actual_mbx;
    // Note: The shared dut_state object is not used by this monitor to create packets for the scoreboard.
    // It could be used to model the DUT's internal state if needed, but the scoreboard needs fresh packets.
    pkt4 dut_state;

    function new(virtual md_if.Transactor md_vif, mailbox #(pkt4) actual_mbx, pkt4 dut_state);
      this.md_vif = md_vif;
      this.actual_mbx = actual_mbx;
      this.dut_state = dut_state;
    endfunction

    task run();
      // The monitor_rx is not strictly needed for checking the aligner's output,
      // but it is good practice to have it. For this fix, we focus on monitor_tx.
      fork
        // monitor_rx();
        monitor_tx();
      join_none
    endtask

    task monitor_rx();
      forever begin
        @(md_vif.transactor_cb);
        // Logic to monitor the RX channel could be added here if needed.
      end
    endtask

    task monitor_tx();
      forever begin
        @(md_vif.transactor_cb);
        if (md_vif.transactor_cb.md_tx_valid && md_vif.transactor_cb.md_tx_ready) begin
          // FIX: Create a new packet, capture the bus values, and send it to the scoreboard.
          // Do not send a handle to a shared static object.
          pkt4 actual_pkt = new();
          actual_pkt.data   = md_vif.transactor_cb.md_tx_data;
          actual_pkt.size   = md_vif.transactor_cb.md_tx_size;
          actual_pkt.offset = md_vif.transactor_cb.md_tx_offset;
          actual_mbx.put(actual_pkt);
        end
      end
    endtask
  endclass

  class Generator;
    mailbox #(apb_pkt) apb_driver_mbx;
    mailbox #(bit)     apb_response_mbx;
    mailbox #(md_pkt)  md_driver_mbx;
    mailbox #(pkt6)   scoreboard_mbx;

    local bit [2:0] dut_cfg_size;
    local bit [1:0] dut_cfg_offset;
    local bit       dut_cfg_enabled;
    local bit [1:0] dut_cfg_encoded_offset;
    int transaction_id_counter;

    function new(mailbox #(apb_pkt) apb_driver_mbx, 
                mailbox #(bit)     apb_response_mbx,
                mailbox #(md_pkt)  md_driver_mbx, 
                mailbox #(pkt6)   scoreboard_mbx);
      this.apb_driver_mbx   = apb_driver_mbx;
      this.apb_response_mbx = apb_response_mbx; // <-- STORE IT
      this.md_driver_mbx    = md_driver_mbx;
      this.scoreboard_mbx   = scoreboard_mbx;
      this.dut_cfg_enabled = 0;
      this.dut_cfg_size    = 3'd4;
      this.dut_cfg_offset  = 2'd0;
      this.transaction_id_counter = 0;
    endfunction

  task configure_dut(bit [2:0] size, bit [1:0] offset, bit [1:0] encoded_offset, bit enabled);
    bit [31:0] ctrl_reg_data;

    // Store the configuration locally for the predictor to use
    this.dut_cfg_enabled = enabled;
    this.dut_cfg_size    = size;
    this.dut_cfg_offset  = offset; // Store the REAL byte offset for the predictor
    this.dut_cfg_encoded_offset = encoded_offset; // Store the ENCODED offset for the DUT

    $display("[Generator] Configuring DUT for size=%0d, offset=%0d, enabled=%0d", size, offset, enabled);

    // Assemble the control word and send it via the blocking APB write
    ctrl_reg_data = {12'b0, dut_cfg_enabled, 8'b0, dut_cfg_size, 6'b0, dut_cfg_encoded_offset};
    send_apb_write('h00, ctrl_reg_data);
  endtask

    task run(pkt1 test_cfg);
    // Loop to generate stimulus
    for (int i = 0; i < test_cfg.num_pkts; i++) begin
      md_pkt input_stimulus_pkt = new();
      pkt6   expected_output_pkt;

      void'(input_stimulus_pkt.randomize() with {
        inter_pkt_time_ns inside {[test_cfg.delay_min_ns : test_cfg.delay_max_ns]};
      });

      md_driver_mbx.put(input_stimulus_pkt);
      expected_output_pkt = this.predict_output(input_stimulus_pkt);
      scoreboard_mbx.put(expected_output_pkt);
     

    end
    begin
      pkt6 final_pkt = new();
      final_pkt.is_last = 1;
      $display("[Generator] All stimulus sent. Sending final packet to scoreboard.");
      scoreboard_mbx.put(final_pkt);
    end
  endtask

    task send_apb_write(bit [15:0] addr, bit [31:0] data);
      apb_pkt pkt = new();
      bit dummy;
      pkt.write_en = 1;
      pkt.addr = addr;
      pkt.data = data;
      apb_driver_mbx.put(pkt);
      apb_response_mbx.get(dummy);
    endtask

    function pkt6 predict_output(md_pkt input_pkt);

        pkt6 predicted_pkt = new();
        bit is_legal_transfer;
        int expected_byte_size;
        $display("[PRED CFG] dut_cfg_offset=%0d, dut_cfg_size=%0d", dut_cfg_offset, dut_cfg_size);

        predicted_pkt.id = transaction_id_counter++;
        if (!dut_cfg_enabled) return predicted_pkt;

        // Map encoded DUT size to actual byte-size
        case (dut_cfg_size)
          0: expected_byte_size = 1;
          1: expected_byte_size = 2;
          2: expected_byte_size = 4;
          default: expected_byte_size = 0;
        endcase

        foreach (input_pkt.data[i]) begin
          is_legal_transfer = (input_pkt.size[i] == expected_byte_size) &&
                              (input_pkt.offset[i] == dut_cfg_offset);

          if (is_legal_transfer) begin
            bit [31:0] input_word;
            bit [31:0] predicted_word;
            int byte_shift;
            bit [31:0] mask;

            input_word = input_pkt.data[i];
            predicted_word = 32'b0;

            // compute shift in bits to align the transferred bytes to LSB
            byte_shift = input_pkt.offset[i] * 8;

            // mask depends on transfer size
            case (input_pkt.size[i])
              1: mask = 32'hFF;
              2: mask = 32'hFFFF;
              4: mask = 32'hFFFF_FFFF;
              default: mask = 32'h0;
            endcase

            // extract the byte/halfword/word from the input word using shift+mask
            predicted_word = (input_word >> byte_shift) & mask;
 
            // store predicted information (use REAL byte offset that the DUT will place)
            predicted_pkt.data.push_back(predicted_word);
            predicted_pkt.size.push_back(input_pkt.size[i]);     // bytes (1/2/4)
            predicted_pkt.offset.push_back(0);
     // the DUT configured byte offset
            $display("[GEN PRED] pkt_id=%0d input_word=0x%08h size=%0d offset=%0d -> predicted_word=0x%08h (stored_offset=%0d)",
                    predicted_pkt.id, input_word, input_pkt.size[i], input_pkt.offset[i], predicted_word, dut_cfg_offset);
          end
        end
        return predicted_pkt;
    endfunction
  endclass

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

  class Checker;
    function new(int data_width = 32, int fifo_depth = 8);
    endfunction
    function void report();
      $display("--- Checker Report ---");
    endfunction
  endclass


  // ===================================================================
  // 4. ENVIRONMENT CLASS
  // ===================================================================

  class environment;
    virtual apb_if.Transactor apb_vif;
    virtual md_if.Transactor  md_vif;
    test_sync sync;
    apb_driver  apb_drv;
    md_driver   md_drv;
    apb_monitor apb_mon;
    md_monitor  md_mon;
    Generator   gen;
    Checker chkr;
    Scoreboard  scb;

    mailbox #(apb_pkt) apb_driver_mbx;
    mailbox #(bit)          apb_response_mbx;
    mailbox #(md_pkt)  md_driver_mbx;
    mailbox #(pkt6)   scoreboard_mbx;
    mailbox #(pkt4)   actual_mbx;

    pkt4 shared_dut_state;

    function new(virtual apb_if.Transactor apb_vif, virtual md_if.Transactor md_vif);
      this.apb_vif = apb_vif;
      this.md_vif  = md_vif;

      sync = new();
      apb_driver_mbx = new();
      apb_response_mbx = new();
      md_driver_mbx  = new();
      scoreboard_mbx = new();
      actual_mbx     = new();
      shared_dut_state = new();

      apb_drv = new(apb_vif, apb_driver_mbx, apb_response_mbx);
      md_drv  = new(md_vif,  md_driver_mbx);
      apb_mon = new(apb_vif, actual_mbx, shared_dut_state);
      md_mon  = new(md_vif,  actual_mbx, shared_dut_state);
      gen = new(apb_driver_mbx, apb_response_mbx, md_driver_mbx, scoreboard_mbx);
      chkr    = new(32, 8);
      scb = new(scoreboard_mbx, actual_mbx, sync);
    endfunction

    task run();
      $display("[%0t] [ENV] Starting environment components...", $time);
      fork
        apb_drv.run();
        md_drv.run();
        apb_mon.run();
        md_mon.run();
        scb.run();
      join_none
    endtask
  endclass


  // ===================================================================
  // 5. TEST CLASSES
  // ===================================================================

  class base_test;
    environment env;
    virtual apb_if.Transactor apb_vif;
    virtual md_if.Transactor  md_vif;

    function new(virtual apb_if.Transactor apb_vif, virtual md_if.Transactor md_vif);
      this.apb_vif = apb_vif;
      this.md_vif  = md_vif;
      env = new(apb_vif, md_vif);
    endfunction

    virtual task run();
      $display("[%0t] [BASE_TEST] Starting common run phase...", $time);
      apb_vif.reset_n <= 1'b0;
      repeat(5) @(posedge apb_vif.pclk);
      apb_vif.reset_n <= 1'b1;
      $display("[%0t] [BASE_TEST] Reset released.", $time);
      @(posedge apb_vif.pclk);
    endtask
  endclass

  class random_md_test extends base_test;
    rand bit [2:0] rand_encoded_size;
    rand bit [1:0] rand_offset;

    // Add constraints to ensure we only pick valid, supported sizes
    constraint c_valid_size {
      // We are randomizing the ENCODED value (0, 1, or 2)
      rand_encoded_size inside {0, 1, 2}; 
    }

    // Add constraints for legal offset/size combinations
    constraint c_valid_combo {
      (rand_encoded_size == 1) -> (rand_offset % 2 == 0); // For 2-byte size, offset must be even
      (rand_encoded_size == 2) -> (rand_offset == 0);      // For 4-byte size, offset must be 0
    }

    function new(virtual apb_if.Transactor apb_vif, virtual md_if.Transactor md_vif);
      super.new(apb_vif, md_vif);
    endfunction

    task run();
      pkt1 test_cfg = new();
      bit [1:0] encoded_offset;
      test_cfg.num_pkts     = 100;
      test_cfg.delay_min_ns = 10;
      test_cfg.delay_max_ns = 50;
      test_cfg.with_window  = 1;

      // FIX: The order of operations was wrong.
      // 1. Call super.run() to apply reset and bring the DUT to a known state.
      super.run();
      // 2. Call env.run() to start the testbench components and generate stimulus.
      env.run();

      if (!this.randomize()) begin
        $fatal(1, "Test randomization failed!");
      end

      
      case (rand_encoded_size)
        0: encoded_offset = rand_offset; // size=1, offset is 0,1,2,3
        1: encoded_offset = rand_offset / 2; // size=2, byte offset 0,2 -> encoded 0,1
        2: encoded_offset = 0; // size=4, byte offset 0 -> encoded 0
      endcase

      env.gen.configure_dut(rand_encoded_size, rand_offset, encoded_offset, 1'b1);
      $display("[TEST CFG] Configured DUT: encoded_size=%0d, rand_offset(real)=%0d, encoded_offset=%0d",
          rand_encoded_size, rand_offset, encoded_offset);

      env.gen.run(test_cfg);
      
      @(env.sync.test_done);
      #100ns;

      $display("[%0t] [TEST] Test sequence complete. Generating reports...", $time);
      env.scb.report();
      env.chkr.report();
    endtask
  endclass


  // ===================================================================
  // 6. TOP-LEVEL TESTBENCH MODULE
  // ===================================================================

  module testbench;
    bit clk;
    wire irq;

    apb_if apb_bus();
    md_if  md_bus();

    // --- FIX: All declarations must come before logic/instantiations ---
    random_md_test test;

    // The DUT instance uses the 'cfs_aligner' from your design.sv file
    cfs_aligner dut (
      .clk(clk),
      .reset_n(apb_bus.reset_n),
      .paddr(apb_bus.paddr),
      .pwrite(apb_bus.pwrite),
      .psel(apb_bus.psel),
      .penable(apb_bus.penable),
      .pwdata(apb_bus.pwdata),
      .pready(apb_bus.pready),
      .prdata(apb_bus.prdata),
      .pslverr(apb_bus.pslverr),
      .md_rx_valid(md_bus.md_rx_valid),
      .md_rx_data(md_bus.md_rx_data),
      .md_rx_offset(md_bus.md_rx_offset),
      .md_rx_size(md_bus.md_rx_size),
      .md_rx_ready(md_bus.md_rx_ready),
      .md_rx_err(md_bus.md_rx_err),
      .md_tx_valid(md_bus.md_tx_valid),
      .md_tx_data(md_bus.md_tx_data),
      .md_tx_offset(md_bus.md_tx_offset),
      .md_tx_size(md_bus.md_tx_size),
      .md_tx_ready(md_bus.md_tx_ready),
      .md_tx_err(md_bus.md_tx_err),
      .irq(irq)
    );

    assign apb_bus.pclk = clk;
    assign md_bus.clk = clk;
    assign md_bus.reset_n = apb_bus.reset_n;

    initial begin
      clk = 0;
      forever #5ns clk = ~clk;
    end

    initial begin
      $display("==== [TB] Starting Testbench ====");
      test = new(apb_bus.Transactor, md_bus.Transactor);
      test.run();
    
      $display("==== [TB] Test Finished ====");
      $finish;
    end

  endmodule