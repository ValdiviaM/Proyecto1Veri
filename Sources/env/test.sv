`include "pkt1.sv"
`include "environment.sv"

// This is the parent class for all tests.
// It handles building the environment and common setup like reset.
class base_test;

  // Handle to the environment
  environment env;

  // Virtual interfaces, needed to pass down to the environment
  virtual apb_if.Transactor apb_vif;
  virtual md_if.Transactor  md_vif;

  // Constructor: receives interfaces from the testbench
  function new(virtual apb_if.Transactor apb_vif, virtual md_if.Transactor md_vif);
    this.apb_vif = apb_vif;
    this.md_vif  = md_vif;
    
    // Build the environment
    env = new(apb_vif, md_vif);
  endfunction

  // This task contains the common startup sequence for ALL tests.
  virtual task run();
    $display("[%0t] [BASE_TEST] Starting common run phase...", $time);
    
    // The reset is now controlled from the test level, not the testbench initial block
    // This gives tests more control if they need to test reset behavior.
    apb_vif.pclk <= 0; // Ensure clock is in a known state
    md_vif.clk   <= 0;
    
    // Apply reset
    env.apb_vif.reset_n <= 1'b0;
    env.md_vif.reset_n  <= 1'b0;
    repeat(5) @(posedge apb_vif.pclk);
    
    // Release reset
    env.apb_vif.reset_n <= 1'b1;
    env.md_vif.reset_n  <= 1'b1;
    $display("[%0t] [BASE_TEST] Reset released.", $time);
    @(posedge apb_vif.pclk);
  endtask

endclass
// This is a specific test case that sends random MD packets.
// It extends the base_test to reuse its setup.
class random_md_test extends base_test;

  // Constructor: simply calls the parent's constructor
  function new(virtual apb_if.Transactor apb_vif, virtual md_if.Transactor md_vif);
    super.new(apb_vif, md_vif);
  endfunction

  // This is the main body of our specific test case
  task run();
    // 1. Run the common setup from the parent class (reset)
    super.run();

    $display("[%0t] [TEST] Starting random_md_test sequence...", $time);

    // 2. Create the test configuration packet (pkt1)
    pkt1 test_cfg = new();

    // 3. Configure the scenario
    test_cfg.num_pkts     = 100; // Generate 100 MD packets
    test_cfg.delay_min_ns = 10;
    test_cfg.delay_max_ns = 50;
    test_cfg.with_window  = 1;   // Example configuration

    // 4. Pass the configuration to the environment and tell it to run.
    //    This is the key step that connects the test to the environment.
    env.run(test_cfg);
    
    $display("[%0t] [TEST] Test sequence generation is complete.", $time);
  endtask

endclass