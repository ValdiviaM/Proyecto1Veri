`include "apb_driver.sv"
`include "md_driver.sv"
`include "apb_monitor.sv"
`include "md_monitor.sv"
`include "generator.sv"
`include "Checker.sv"
`include "scoreboard.sv"

class environment;

  // Virtual Interfaces for connecting to the DUT
  virtual apb_if.Transactor apb_vif;
  virtual md_if.Transactor  md_vif;

  // Component Handles
  apb_driver  apb_drv;
  md_driver   md_drv;
  apb_monitor apb_mon;
  md_monitor  md_mon;
  Generator   gen;
  checker     chkr;
  Scoreboard  scb;

  // Mailboxes for component communication
  mailbox #(apb_pkt) apb_driver_mbx;
  mailbox #(md_pkt)  md_driver_mbx;
  mailbox #(pkt6)   scoreboard_mbx;
  mailbox #(pkt4)   actual_mbx;     // From monitors to checker

  // Shared state object for monitors to build a coherent picture of the DUT
  pkt4 shared_dut_state;

  // Constructor: The "Build" Phase
  function new(virtual apb_if.Transactor apb_vif, virtual md_if.Transactor md_vif);
    this.apb_vif = apb_vif;
    this.md_vif  = md_vif;

    // 1. Create the mailboxes (the "pipes")
    apb_driver_mbx = new();
    md_driver_mbx  = new();
    scoreboard_mbx = new();
    actual_mbx     = new();
    
    // 2. Create the shared state object
    shared_dut_state = new();

    // 3. Create all verification components and connect them
    apb_drv = new(apb_vif, apb_driver_mbx);
    md_drv  = new(md_vif,  md_driver_mbx);
    
    apb_mon = new(apb_vif, actual_mbx, shared_dut_state);
    md_mon  = new(md_vif,  actual_mbx, shared_dut_state);
    
    gen = new(apb_driver_mbx, md_driver_mbx, scoreboard_mbx);
    
    // Assuming DUT parameters are 32-bit width and FIFO depth of 8
    chkr = new(32, 8); 
    
    // The scoreboard connects to the generator (for expected) and monitors (for actual)
    scb = new(scoreboard_mbx, actual_mbx); // Note: Your scoreboard may need adjustment to accept 'actual_mbx'
  endfunction

  // Main Task: The "Run" Phase
  task run(pkt1 test_cfg);
    $display("[%0t] [ENV] Starting environment...", $time);

    // 1. Start all background processes (drivers, monitors, checker, scoreboard)
    fork
      apb_drv.run();
      md_drv.run();
      apb_mon.run();
      md_mon.run();
      // chkr.run(); // Add run task to checker if it has one
      scb.run();
    join_none

    // 2. Start the generator with the specific test configuration
    gen.run(test_cfg);

    // 3. Wait some time for the last packets to be processed by the DUT and scoreboard
    #200ns;

    // 4. Final step: report results
    $display("[%0t] [ENV] Simulation finished. Generating reports...", $time);
    scb.report();
    chkr.report();
    
  endtask

endclass