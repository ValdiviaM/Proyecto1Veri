class apb_monitor;
    virtual apb_if.Transactor apb_vif;
    mailbox #(pkt4) actual_mbx;
    pkt4 dut_state;

    localparam ADDR_CTRL   = 16'h00;
    localparam ADDR_IRQ_EN = 16'h08;

    function new(virtual apb_if.Transactor apb_vif, mailbox #(pkt4) actual_mbx, pkt4 dut_state);
      this.apb_vif = apb_vif;
      this.actual_mbx = actual_mbx;
      this.dut_state = dut_state;
    endfunction

  task run();
    forever begin
      @(apb_vif.master_cb);
      if (apb_vif.psel && apb_vif.penable && apb_vif.pready) begin
        if (apb_vif.pwrite) begin
          $display("[APB_MON] Write to %h with %h", apb_vif.paddr, apb_vif.pwdata);
        end
      end
    end
  endtask
  endclass