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
      //(SETUP phase: psel=1, penable=0)
      if (vif.mon_cb.psel && !vif.mon_cb.penable) begin
        apb_transaction tx = new();

        //Capturar las senales de SETUP phase
        tx.addr = vif.mon_cb.paddr;
        tx.op   = vif.mon_cb.pwrite ? APB_WRITE : APB_READ;
        
        if (tx.op == APB_WRITE) begin
          tx.wdata = vif.mon_cb.pwdata;
        end

        //Moverse a la ACCESS phase
        @(vif.mon_cb);
        //Esperar por el pready (transaction completion)
        wait (vif.mon_cb.pready);
        
        //Capturar resultados ACCESS phase
        if (tx.op == APB_READ) begin
          tx.rdata = vif.mon_cb.prdata;
        end

        //CApturar senales de error - para sincronizar ambos campos
        tx.slverr = vif.mon_cb.pslverr;
        tx.error  = vif.mon_cb.pslverr;  // mantener sincronizado con el slverr

        mon_mbx.put(tx);
        
        //Display de la transaccion capturada
        if (tx.op == APB_READ) begin
          if (tx.error) begin
            $display("[%s] Lectura Capturada [ERROR]: addr=0x%h, rdata=0x%h, slverr=%b", 
                     name, tx.addr, tx.rdata, tx.slverr);
          end else begin
            $display("[%s] Lectura Capturada: addr=0x%h, rdata=0x%h", 
                     name, tx.addr, tx.rdata);
          end
        end else begin
          if (tx.error) begin
            $display("[%s] Escritura Capturada [ERROR]: addr=0x%h, wdata=0x%h, slverr=%b", 
                     name, tx.addr, tx.wdata, tx.slverr);
          end else begin
            $display("[%s] Escritura Capturada: addr=0x%h, wdata=0x%h", 
                     name, tx.addr, tx.wdata);
          end
        end
      end
    end
  endtask

  
