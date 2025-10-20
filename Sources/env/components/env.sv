
  class environment;
    virtual apb_if.Transactor apb_vif;
    virtual md_if.Transactor  md_vif;
    virtual md_if_monitor.Monitor md_monitor_vif;
    test_sync sync;
    apb_driver  apb_drv;
    md_driver   md_drv;
    apb_monitor apb_mon;
    md_monitor  md_mon;
    Generator   gen;
    Checker chkr;
    Scoreboard  scb;

    mailbox #(apb_pkt) apb_driver_mbx;
    mailbox #(bit)          apb_response_mbx;
    mailbox #(md_pkt)  md_driver_mbx;
    mailbox #(pkt6)   scoreboard_mbx;
    mailbox #(pkt4)   actual_mbx;

    pkt4 shared_dut_state;

    function new(virtual apb_if.Transactor apb_vif, virtual md_if.Transactor md_vif);
      this.apb_vif = apb_vif;
      this.md_vif  = md_vif;

      sync = new();
      apb_driver_mbx = new();
      apb_response_mbx = new();
      md_driver_mbx  = new();
      scoreboard_mbx = new();
      actual_mbx     = new();
      shared_dut_state = new();

      apb_drv = new(apb_vif, apb_driver_mbx, apb_response_mbx);
      md_drv  = new(md_vif,  md_driver_mbx);
      apb_mon = new(apb_vif, actual_mbx, shared_dut_state);
      md_mon  = new(md_monitor_vif,  actual_mbx, shared_dut_state);
      gen = new(apb_driver_mbx, apb_response_mbx, md_driver_mbx, scoreboard_mbx);
      chkr    = new(32, 8);
      scb = new(scoreboard_mbx, actual_mbx, sync);
    endfunction

    task run();
      $display("[%0t] [ENV] Starting environment components...", $time);
      fork
        apb_drv.run();
        md_drv.run();
        apb_mon.run();
        md_mon.run();
        scb.run();
      join_none
    endtask
  endclass