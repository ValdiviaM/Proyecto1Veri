class apb_driver;
  virtual apb_if.Transactor apb_vif;
  mailbox #(apb_pkt) drv_mbx;

  function new(virtual apb_if.Transactor apb_vif, mailbox #(apb_pkt) drv_mbx);
    this.apb_vif = apb_vif;
    this.drv_mbx = drv_mbx;
  endfunction

  // This task runs forever, waiting for packets from the generator
  task run();
    forever begin
      apb_pkt pkt;
      drv_mbx.get(pkt); // Wait for a transaction
      drive_transaction(pkt);
    end
  endtask

  // This is the original 'drive' logic, now as a helper task
  task drive_transaction(apb_pkt p);
    // ... (The exact APB protocol driving logic from our previous discussion)
    // Phase SETUP
    apb_vif.master_cb.psel   <= 1'b1;
    apb_vif.master_cb.paddr  <= p.addr;
    apb_vif.master_cb.pwrite <= p.write_en;
    apb_vif.master_cb.pwdata <= p.data;
    @(apb_vif.master_cb);
    // Phase ACCESS
    apb_vif.master_cb.penable <= 1'b1;
    while (!apb_vif.master_cb.pready) @(apb_vif.master_cb);
    @(apb_vif.master_cb);
    // Phase IDLE
    apb_vif.master_cb.psel    <= 1'b0;
    apb_vif.master_cb.penable <= 1'b0;
  endtask
endclass