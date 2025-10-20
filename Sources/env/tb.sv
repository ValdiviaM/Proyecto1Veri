`include "interfaces/apb_if.sv"
`include "interfaces/md_if.sv"

`include "packets/test_sync.sv"
`include "packets/pkt1.sv"
`include "packets/pkt_base.sv"
`include "packets/apb_pkt.sv"
`include "packets/md_pkt.sv"
`include "packets/pkt4.sv"
`include "packets/pkt6.sv"

`include "transactors/apb_driver.sv"
`include "transactors/md_driver.sv"
`include "transactors/apb_monitor.sv"
`include "transactors/md_monitor.sv"

`include "components/Generator.sv"
`include "components/Scoreboard.sv"
`include "components/Checker.sv"
`include "components/env.sv"

`include "tests/base_test.sv"
`include "tests/random_md_test.sv"

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