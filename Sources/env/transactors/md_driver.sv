class md_driver;
    virtual md_if.Transactor md_vif;
    mailbox #(md_pkt) drv_mbx;

    function new(virtual md_if.Transactor md_vif, mailbox #(md_pkt) drv_mbx);
      this.md_vif = md_vif;
      this.drv_mbx = drv_mbx;
    endfunction

    task run();
      fork
        run_tx_handler();
        run_rx_sender();
      join_none
    endtask

    task run_rx_sender();
      forever begin
        md_pkt pkt;
        drv_mbx.get(pkt);
        drive_transaction(pkt);
      end
    endtask

    task run_tx_handler();
      md_vif.transactor_cb.md_tx_ready <= 1'b1;
      md_vif.transactor_cb.md_tx_err   <= 1'b0;
      forever @(md_vif.transactor_cb);
    endtask

    task drive_transaction(md_pkt p);
      if (p.inter_pkt_time_ns > 0) begin
        md_vif.transactor_cb.md_rx_valid <= 1'b0;
        // FIX: Use the clocking block for all delays to avoid race conditions.
        // The clock period is 10ns, so divide by 10.


        repeat(p.inter_pkt_time_ns / 10) @(md_vif.transactor_cb);
      end

      foreach(p.data[i]) begin
        md_vif.transactor_cb.md_rx_valid  <= 1'b1;
        md_vif.transactor_cb.md_rx_data   <= p.data[i];
        md_vif.transactor_cb.md_rx_size   <= p.size[i];
        md_vif.transactor_cb.md_rx_offset <= p.offset[i];
        do @(md_vif.transactor_cb); while (!md_vif.transactor_cb.md_rx_ready);
        $display("[MD_DRV] driving md_rx_data=0x%08h size=%0d offset=%0d (wait for md_rx_ready)",
         p.data[i], p.size[i], p.offset[i]);
      end
      md_vif.transactor_cb.md_rx_valid <= 1'b0;
      @(md_vif.transactor_cb);
    endtask
  endclass