`include "pkt2.sv"
`include "MD_IF.sv"

class md_driver;
  virtual md_if.Transactor md_vif;

  function new(virtual md_if.Transactor md_vif);
    this.md_vif = md_vif;
  endfunction

  task drive(pkt2 p, real clk_period_ns);
    int delay_cycles = (p.inter_pkt_time_ns / clk_period_ns);
    repeat(delay_cycles) @(posedge md_vif.clk);

    // Send packet hacia DUT (RX)
    foreach(p.data[i]) begin
      md_vif.md_rx_valid  <= 1;
      md_vif.md_rx_data   <= p.data[i];
      md_vif.md_rx_size   <= p.size[i];
      md_vif.md_rx_offset <= p.offset[i];

      wait(md_vif.md_rx_ready);
      @(posedge md_vif.clk);
      md_vif.md_rx_valid <= 0;
    end

    // Captura de datos de TX si DUT responde
    if (md_vif.md_tx_valid) begin
      foreach(p.data[i]) begin
        p.data_out[i] = md_vif.md_tx_data;
        // opcional: captura size/offset si interesa
      end
    end
  endtask
endclass
