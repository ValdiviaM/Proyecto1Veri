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
      if (apb_vif.master_cb.psel && apb_vif.master_cb.penable && apb_vif.master_cb.pready) begin
        if (apb_vif.master_cb.pwrite) begin
          // FIX: This monitor should observe the bus, but not send packets to the scoreboard.
          // The line below has been removed.
          // actual_mbx.put(dut_state);
          
          // Optionally, you could add a display here for debugging purposes.
          $display("[APB_MON] Detected APB write to addr %h with data %h", 
                  apb_vif.master_cb.paddr, apb_vif.master_cb.pwdata);
        end
      end
    end
  endtask
  endclass