'include "pkt5.sv"

class monitor;

  //Estadisticas
  int apb_transactions;
  int md_rx_transactions;
  int md_tx_transactions;
  int irq_events;
  int reset_events;
  int illegal_transfers;

//Seleccion de senales
   task monitor_signals(
    // Normalmente estos serían de una virtual interface
    input bit clk,
    input bit reset_n,
    input bit psel, penable, pwrite,
    input bit [15:0] paddr,
    input bit [31:0] pwdata, prdata,
    input bit pready, pslverr,
    input bit md_rx_valid, md_rx_ready, md_rx_err,
    input bit [31:0] md_rx_data,
    input bit [1:0] md_rx_offset,
    input bit [2:0] md_rx_size,
    input bit md_tx_valid, md_tx_ready, md_tx_err,
    input bit [31:0] md_tx_data,
    input bit [1:0] md_tx_offset,
    input bit [2:0] md_tx_size,
    input bit irq,
    input bit [2:0] ctrl_size,
    input bit [1:0] ctrl_offset,
    input bit [7:0] status_cnt_drop,
    input bit [3:0] status_rx_lvl, status_tx_lvl,
    input bit [4:0] irqen, irq_flags
  );
  pkt5 pkt;
  if (!enable) return;
    
    @(posedge clk);
    
    // Crear nuevo paquete
    pkt = new()

    //
endclass