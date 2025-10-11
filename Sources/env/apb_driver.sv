// apb_driver.sv
`include "pkt3.sv"
`include "apb_driver.sv"

class apb_driver;
  virtual apb_if.master apb_vif;

  function new(virtual apb_if.master apb_vif);
    this.apb_vif = apb_vif;
  endfunction

  task drive(pkt p);
    p.display("[APB] Driving: ");

    // APB transaction
    apb_vif.psel    <= 1'b1;
    apb_vif.paddr   <= p.addr;
    apb_vif.pwrite  <= p.write_en;
    apb_vif.pwdata  <= p.wdata;
    apb_vif.penable <= 1'b0;
    @(posedge apb_vif.pclk);
    apb_vif.penable <= 1'b1;

    // Wait for ready
    wait(apb_vif.pready);
    if (!p.write_en)
      p.rdata = apb_vif.prdata;

    // Return to idle
    apb_vif.psel    <= 1'b0;
    apb_vif.penable <= 1'b0;
    @(posedge apb_vif.pclk);
  endtask
endclass
