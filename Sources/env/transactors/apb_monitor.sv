class apb_monitor;
  string name = "APB_Monitor";
  
  // 1. La interfaz virtual ahora está calificada con el modport del Monitor
  virtual apb_interface.Monitor vif; 
  mailbox #(apb_transaction) mon_mbx;

  // 2. El constructor ahora espera un handle al modport del Monitor
  function new(virtual apb_interface.Monitor vif, mailbox #(apb_transaction) mon_mbx);
    this.vif = vif;
    this.mon_mbx = mon_mbx;
  endfunction

  task run();
    $display("[%s] El monitor ha comenzado a observar la interfaz.", name);
    forever begin
      // 3. Reemplazamos TODAS las referencias al clocking block por 'mon_cb'
      @(vif.mon_cb);
      if (vif.mon_cb.psel && !vif.mon_cb.penable) begin
        apb_transaction tx = new();
        tx.addr = vif.mon_cb.paddr;
        tx.op   = vif.mon_cb.pwrite ? APB_WRITE : APB_READ;
        if (tx.op == APB_WRITE) begin
          tx.wdata = vif.mon_cb.pwdata;
        end

        @(vif.mon_cb);
        wait (vif.mon_cb.pready);
        
        if (tx.op == APB_READ) begin
          tx.rdata = vif.mon_cb.prdata;
        end
        tx.slverr = vif.mon_cb.pslverr;
        mon_mbx.put(tx);
        
        if(tx.op == APB_READ)
          $display("[%s] Lectura Capturada: addr=%h, rdata=%h, slverr=%b", name, tx.addr, tx.rdata, tx.slverr);
        else
          $display("[%s] Escritura Capturada: addr=%h, wdata=%h, slverr=%b", name, tx.addr, tx.wdata, tx.slverr);
      end
    end
  endtask
endclass
