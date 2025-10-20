class md_monitor;
    virtual md_if.Transactor md_vif;
    mailbox #(pkt4) actual_mbx;
    // Note: The shared dut_state object is not used by this monitor to create packets for the scoreboard.
    // It could be used to model the DUT's internal state if needed, but the scoreboard needs fresh packets.
    pkt4 dut_state;

    function new(virtual md_if.Transactor md_vif, mailbox #(pkt4) actual_mbx, pkt4 dut_state);
      this.md_vif = md_vif;
      this.actual_mbx = actual_mbx;
      this.dut_state = dut_state;
    endfunction

    task run();
      // The monitor_rx is not strictly needed for checking the aligner's output,
      // but it is good practice to have it. For this fix, we focus on monitor_tx.
      fork
        // monitor_rx();
        monitor_tx();
      join_none
    endtask

    task monitor_rx();
      forever begin
        @(md_vif.transactor_cb);
        // Logic to monitor the RX channel could be added here if needed.
      end
    endtask

    task monitor_tx();
      forever begin
        @(md_vif.transactor_cb);
        if (md_vif.transactor_cb.md_tx_valid && md_vif.transactor_cb.md_tx_ready) begin
          // FIX: Create a new packet, capture the bus values, and send it to the scoreboard.
          // Do not send a handle to a shared static object.
          pkt4 actual_pkt = new();
          actual_pkt.data   = md_vif.transactor_cb.md_tx_data;
          actual_pkt.size   = md_vif.transactor_cb.md_tx_size;
          actual_pkt.offset = md_vif.transactor_cb.md_tx_offset;
          actual_mbx.put(actual_pkt);
        end
      end
    endtask
  endclass