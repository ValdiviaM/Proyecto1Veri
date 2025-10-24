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
      @(vif.mon_cb);
      // (SETUP phase: psel=1, penable=0)
      if (vif.mon_cb.psel && !vif.mon_cb.penable) begin
        apb_transaction tx = new();

        // Capturar señales de SETUP phase
        tx.addr = vif.mon_cb.paddr;
        tx.op   = vif.mon_cb.pwrite ? APB_WRITE : APB_READ;
        if (tx.op == APB_WRITE)
          tx.wdata = vif.mon_cb.pwdata;

        // Moverse a la ACCESS phase
        @(vif.mon_cb);
        wait (vif.mon_cb.pready);
        
        // Capturar resultados ACCESS phase
        if (tx.op == APB_READ)
          tx.rdata = vif.mon_cb.prdata;

        // Capturar errores
        tx.slverr = vif.mon_cb.pslverr;
        tx.error  = vif.mon_cb.pslverr; // sincronizado con slverr

        mon_mbx.put(tx);
        
        // Display de la transacción capturada
        if (tx.op == APB_READ) begin
          if (tx.error)
            $display("[%s] Lectura Capturada [ERROR]: addr=0x%h, rdata=0x%h, slverr=%b", 
                     name, tx.addr, tx.rdata, tx.slverr);
          else
            $display("[%s] Lectura Capturada: addr=0x%h, rdata=0x%h", 
                     name, tx.addr, tx.rdata);
        end else begin
          if (tx.error)
            $display("[%s] Escritura Capturada [ERROR]: addr=0x%h, wdata=0x%h, slverr=%b", 
                     name, tx.addr, tx.wdata, tx.slverr);
          else
            $display("[%s] Escritura Capturada: addr=0x%h, wdata=0x%h", 
                     name, tx.addr, tx.wdata);
        end
      end
    end
  endtask
endclass

