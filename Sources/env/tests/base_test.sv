class base_test;
    environment env;

    // Add handles for the monitor VIFs
    virtual apb_if.Transactor apb_vif;
    virtual apb_if.Monitor    apb_monitor_vif; // <<< ADD
    virtual md_if.Transactor  md_vif;
    virtual md_if.Monitor     md_monitor_vif;  // <<< ADD

    // Update the constructor to accept all four
    function new(virtual apb_if.Transactor apb_vif,
                 virtual apb_if.Monitor    apb_monitor_vif, // <<< ADD
                 virtual md_if.Transactor  md_vif,
                 virtual md_if.Monitor     md_monitor_vif); // <<< ADD

      this.apb_vif = apb_vif;
      this.apb_monitor_vif = apb_monitor_vif; // <<< ADD
      this.md_vif  = md_vif;
      this.md_monitor_vif = md_monitor_vif;   // <<< ADD

      // Pass all four VIFs to the environment's constructor
      env = new(apb_vif, apb_monitor_vif, md_vif, md_monitor_vif); // <<< FIX
    endfunction

    virtual task run();
      $display("[%0t] [BASE_TEST] Starting common run phase...", $time);
      apb_vif.reset_n <= 1'b0;
      repeat(5) @(posedge apb_vif.pclk);
      apb_vif.reset_n <= 1'b1;
      $display("[%0t] [BASE_TEST] Reset released.", $time);
      @(posedge apb_vif.pclk);
    endtask
  endclass  