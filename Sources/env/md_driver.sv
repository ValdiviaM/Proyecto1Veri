// md_driver.sv
`include "pkt3.sv"
`include "MD_IF.sv"

class md_driver;
  virtual md_if.Transactor md_vif;

  function new(virtual md_if.master md_vif);
    this.md_vif = md_vif;
  endfunction

  task drive(pkt p);
    p.display("[MD] Driving: ");
    
    // Wait between packets
    repeat (p.delay_cycles) @(posedge md_vif.clk);

    // Send packet (RX direction)
    md_vif.md_rx_valid <= 1;
    md_vif.md_rx_data  <= p.data_in;
    md_vif.md_rx_size  <= p.size;
    md_vif.md_rx_offset<= p.offset;

    wait(md_vif.md_rx_ready);
    @(posedge md_vif.clk);
    md_vif.md_rx_valid <= 0;

    // Optionally handle TX return if protocol requires
    if (md_vif.md_tx_valid) begin
      p.data_out = md_vif.md_tx_data;
    end
  endtask
endclass
