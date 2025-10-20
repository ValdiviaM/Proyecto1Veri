
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