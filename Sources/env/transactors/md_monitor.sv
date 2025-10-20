class md_monitor;
    virtual md_if.Monitor md_vif;
    mailbox #(pkt4) actual_mbx;
    // Note: The shared dut_state object is not used by this monitor to create packets for the scoreboard.
    // It could be used to model the DUT's internal state if needed, but the scoreboard needs fresh packets.
    pkt4 dut_state;

    function new(virtual md_if.Monitor md_vif, mailbox #(pkt4) actual_mbx, pkt4 dut_state);      this.md_vif = md_vif;
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
        // Use the monitor's clocking block
        @(md_vif.monitor_cb); // <<< CHANGED to use the monitor_cb
        // This 'if' statement is now valid because all signals are inputs in monitor_cb
        if (md_vif.monitor_cb.md_tx_valid && md_vif.monitor_cb.md_tx_ready) begin
          pkt4 actual_pkt = new();
          actual_pkt.data   = md_vif.monitor_cb.md_tx_data;
          actual_pkt.size   = md_vif.monitor_cb.md_tx_size;
          actual_pkt.offset = md_vif.monitor_cb.md_tx_offset;
          actual_mbx.put(actual_pkt);
        end
      end
    endtask
  endclass