class base_test;
    environment env;
    virtual apb_if.Transactor apb_vif;
    virtual md_if.Transactor  md_vif;

    function new(virtual apb_if.Transactor apb_vif, virtual md_if.Transactor md_vif);
      this.apb_vif = apb_vif;
      this.md_vif  = md_vif;
      env = new(apb_vif, md_vif);
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