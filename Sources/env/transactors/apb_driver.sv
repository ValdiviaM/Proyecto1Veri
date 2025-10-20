class apb_driver;
    virtual apb_if.Transactor apb_vif;
    mailbox #(apb_pkt) drv_mbx;
    mailbox #(bit)          rsp_mbx;

    function new(virtual apb_if.Transactor apb_vif, 
                mailbox #(apb_pkt) drv_mbx, 
                mailbox #(bit) rsp_mbx);
      this.apb_vif = apb_vif;
      this.drv_mbx = drv_mbx;
      this.rsp_mbx = rsp_mbx; // <-- STORE IT
    endfunction

    task run();
      forever begin
        apb_pkt pkt;
        drv_mbx.get(pkt);
        drive_transaction(pkt);
      end
    endtask

    task drive_transaction(apb_pkt p);
      apb_vif.master_cb.psel   <= 1'b1;
      apb_vif.master_cb.paddr  <= p.addr;
      apb_vif.master_cb.pwrite <= p.write_en;
      apb_vif.master_cb.pwdata <= p.data;
      @(apb_vif.master_cb);
      apb_vif.master_cb.penable <= 1'b1;
      while (!apb_vif.master_cb.pready) @(apb_vif.master_cb);
      @(apb_vif.master_cb);
      apb_vif.master_cb.psel    <= 1'b0;
      apb_vif.master_cb.penable <= 1'b0;
      rsp_mbx.put(1'b1);
    endtask
  endclass