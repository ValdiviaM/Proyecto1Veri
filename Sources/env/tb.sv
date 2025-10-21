`include "DUT/design.v"
`include "interfaces/apb_if.sv"
`include "interfaces/md_if.sv"

`include "packets/apb_transaction.sv"
`include "packets/config_pkt.sv"
`include "packets/md_packet.sv"

`include "transactors/apb_driver.sv"
`include "transactors/md_driver.sv"
`include "transactors/apb_monitor.sv"
`include "transactors/md_monitor.sv"

`include "components/Generator.sv"
`include "components/Checker.sv"
`include "components/csv_logger.sv"
`include "components/Scoreboard.sv"
`include "components/env.sv"

`include "tests/test.sv"

 module top_tb;
  //--- Parámetros del Testbench (configuran el DUT y las interfaces) ---//
  parameter ALGN_DATA_WIDTH = 32;
  parameter FIFO_DEPTH      = 8;
  parameter APB_ADDR_WIDTH    = 16;
  
  //--- Reloj y Reset ---//
  logic clk;
  logic reset_n;

  //--- Instanciación de Interfaces ---//
  // Se crea una interfaz por cada puerto del DUT, conectando clk y reset
  apb_interface #(
    .APB_ADDR_WIDTH(APB_ADDR_WIDTH),
    .APB_DATA_WIDTH(ALGN_DATA_WIDTH)
  ) apb_if ();
  assign apb_if.clk     = clk;
  assign apb_if.reset_n = reset_n;
 
  md_interface #(.ALGN_DATA_WIDTH(ALGN_DATA_WIDTH)) md_rx_if();
  assign md_rx_if.clk     = clk;
  assign md_rx_if.reset_n = reset_n;

  md_interface #(.ALGN_DATA_WIDTH(ALGN_DATA_WIDTH)) md_tx_if();
  assign md_tx_if.clk     = clk;
  assign md_tx_if.reset_n = reset_n;

  assign md_tx_if.ready = 1'b1;
  assign md_tx_if.err   = 1'b0;
  //--- Instanciación del DUT (Device Under Test) ---//
  cfs_aligner #(
    .ALGN_DATA_WIDTH(ALGN_DATA_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH)
  ) dut (
    .clk(clk),
    .reset_n(reset_n),
    
    // Conexión del bus APB
    .paddr(apb_if.paddr),
    .pwrite(apb_if.pwrite),
    .psel(apb_if.psel),
    .penable(apb_if.penable),
    .pwdata(apb_if.pwdata),
    .pready(apb_if.pready),
    .prdata(apb_if.prdata),
    .pslverr(apb_if.pslverr),
    
    // Conexión del bus de entrada MD (RX)
    .md_rx_valid(md_rx_if.valid),
    .md_rx_data(md_rx_if.data),
    .md_rx_offset(md_rx_if.offset),
    .md_rx_size(md_rx_if.size),
    .md_rx_ready(md_rx_if.ready),
    .md_rx_err(md_rx_if.err),
    
    // Conexión del bus de salida MD (TX)
    .md_tx_valid(md_tx_if.valid),
    .md_tx_data(md_tx_if.data),
    .md_tx_offset(md_tx_if.offset),
    .md_tx_size(md_tx_if.size),
    .md_tx_ready(md_tx_if.ready),
    .md_tx_err(md_tx_if.err),
    
    .irq() // irq no se verifica en este entorno, se deja desconectado
  );

  //--- Generación de Reloj y Reset ---//
  initial begin
    clk = 0;
    forever #5ns clk = ~clk; // Reloj de 100 MHz
  end

  initial begin
    reset_n = 1'b0;
    $display("[TB] Reset Activo");
    repeat(5) @(posedge clk);
    reset_n = 1'b1;
    $display("[TB] Reset Inactivo. Simulación comienza.");
  end

  //--- Ejecución del Test ---//
  initial begin
    test my_test = new();
    
    // Pasa los handles de las interfaces al test para que las distribuya
    my_test.run(md_rx_if, md_tx_if, apb_if);
    #100;
  end

  // Opcional: Para dumpear las ondas para depuración visual (ej. con DVE o Verdi)
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, top_tb);
  end

endmodule
