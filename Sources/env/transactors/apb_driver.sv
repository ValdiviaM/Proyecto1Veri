class apb_driver;

  string name = "APB_Driver";
  // El driver usa el modport 'Driver' de la interfaz
  virtual apb_interface.Driver vif; 
  mailbox #(apb_transaction) drv_mbx;

  function new(virtual apb_interface.Driver vif, mailbox #(apb_transaction) drv_mbx);
    this.vif = vif;
    this.drv_mbx = drv_mbx;
  endfunction

  task run();
    $display("[%s] El driver ha comenzado.", name);
    reset_signals();

    forever begin
      apb_transaction tx;
      drv_mbx.get(tx);
      $display("[%s] Recibida transacción: %s en dirección 0x%h", name, tx.op.name(), tx.addr);
      case(tx.op)
        APB_WRITE: drive_write(tx);
        APB_READ:  drive_read(tx);
      endcase
    end
  endtask

  protected task drive_write(apb_transaction tx);
    // --- FASE DE SETUP ---
    @(vif.drv_cb); // <-- CORREGIDO de tb_cb a drv_cb
    vif.drv_cb.psel   <= 1'b1;
    vif.drv_cb.pwrite <= 1'b1;
    vif.drv_cb.paddr  <= tx.addr;
    vif.drv_cb.pwdata <= tx.wdata;

    // --- FASE DE ACCESS ---
    @(vif.drv_cb); // <-- CORREGIDO de tb_cb a drv_cb
    vif.drv_cb.penable <= 1'b1;
    
    while (!vif.drv_cb.pready) begin // <-- CORREGIDO de tb_cb a drv_cb
      @(vif.drv_cb); // <-- CORREGIDO de tb_cb a drv_cb
    end
    
    @(vif.drv_cb); // <-- CORREGIDO de tb_cb a drv_cb
    reset_signals();
    $display("[%s] Escritura en 0x%h completada.", name, tx.addr);
  endtask

  protected task drive_read(apb_transaction tx);
    // --- FASE DE SETUP ---
    @(vif.drv_cb); // <-- CORREGIDO de tb_cb a drv_cb
    vif.drv_cb.psel   <= 1'b1;
    vif.drv_cb.pwrite <= 1'b0;
    vif.drv_cb.paddr  <= tx.addr;
    
    // --- FASE DE ACCESS ---
    @(vif.drv_cb); // <-- CORREGIDO de tb_cb a drv_cb
    vif.drv_cb.penable <= 1'b1;

    while (!vif.drv_cb.pready) begin // <-- CORREGIDO de tb_cb a drv_cb
      @(vif.drv_cb); // <-- CORREGIDO de tb_cb a drv_cb
    end
    
    tx.rdata   = vif.drv_cb.prdata; // <-- CORREGIDO de tb_cb a drv_cb
    tx.slverr  = vif.drv_cb.pslverr; // <-- CORREGIDO de tb_cb a drv_cb
    
    @(vif.drv_cb); // <-- CORREGIDO de tb_cb a drv_cb
    reset_signals();
    $display("[%s] Lectura de 0x%h completada. Datos: 0x%h", name, tx.addr, tx.rdata);
  endtask
  
  protected task reset_signals();
      vif.drv_cb.psel    <= 1'b0; // <-- CORREGIDO de tb_cb a drv_cb
      vif.drv_cb.penable <= 1'b0; // <-- CORREGIDO de tb_cb a drv_cb
      vif.drv_cb.paddr   <= 'x;   // <-- CORREGIDO de tb_cb a drv_cb
      vif.drv_cb.pwdata  <= 'x;   // <-- CORREGIDO de tb_cb a drv_cb
  endtask

endclass