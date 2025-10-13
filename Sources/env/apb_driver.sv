`include "pkt2.sv"
`include "APB_IF.sv"

class apb_driver;
  virtual apb_if.Transactor apb_vif;

  function new(virtual apb_if.Transactor apb_vif);
    this.apb_vif = apb_vif;
  endfunction

  task drive(pkt2 p, real clk_period_ns);
    // Convert inter-packet time a ciclos de reloj
    int delay_cycles = (p.inter_pkt_time_ns / clk_period_ns);
    repeat(delay_cycles) @(posedge apb_vif.pclk);

    // APB write/read transaction
    apb_vif.psel    <= 1'b1;
    apb_vif.paddr   <= p.addr;       // si quieres, agrega addr a pkt2
    apb_vif.pwrite  <= p.write_en;   // idem
    apb_vif.pwdata  <= p.data[0];    // simplificación: primer word
    apb_vif.penable <= 1'b0;
    @(posedge apb_vif.pclk);
    apb_vif.penable <= 1'b1;

    // Wait for ready
    wait (apb_vif.pready);
    if (!p.write_en) p.data_out = apb_vif.prdata; // captura salida

    // Idle
    apb_vif.psel    <= 1'b0;
    apb_vif.penable <= 1'b0;
    @(posedge apb_vif.pclk);
  endtask
endclass
