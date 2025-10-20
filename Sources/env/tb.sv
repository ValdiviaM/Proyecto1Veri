`include "cfs_aligner.v"
`include "apb_if.sv"
`include "md_if.sv"
`include "random_md_test.sv" // Include the specific test we want to run

module testbench;

  // Clock and Reset
  bit clk;
  // The reset signal is now inside the interface for better encapsulation
  // bit reset_n; 

  // Instantiate Interfaces
  apb_if apb_bus();
  md_if  md_bus();

  // Instantiate DUT
  cfs_aligner #(
    .ALGN_DATA_WIDTH(32),
    .FIFO_DEPTH(8)
  ) dut (
    .clk(clk),
    .reset_n(apb_bus.reset_n), // Connect reset from one of the interfaces
    // Connect APB and MD interfaces
    .paddr(apb_bus.paddr),
    .pwrite(apb_bus.pwrite),
    // ... connect all other DUT ports to the interfaces
  );
  
  // Connect clock to interfaces
  assign apb_bus.pclk = clk;
  assign md_bus.clk = clk;
  // Tie resets together
  assign md_bus.reset_n = apb_bus.reset_n;

  // Instantiate the Test Class
  random_md_test test;

  // Clock Generation
  initial begin
    clk = 0;
    forever #5ns clk = ~clk; // 10ns period = 100MHz clock
  end

  // Main Test Execution
  initial begin
    $display("==== [TB] Starting Testbench ====");
    
    // 1. Instantiate the test class, passing the virtual interfaces to it
    test = new(apb_bus.Transactor, md_bus.Transactor);
    
    // 2. Start the test. This will call the run() task inside our random_md_test
    test.run();

    // 3. Give the simulation some time to drain final transactions
    #1000ns;

    // 4. Finish simulation
    $display("==== [TB] Test Finished ====");
    $finish;
  end

endmodule