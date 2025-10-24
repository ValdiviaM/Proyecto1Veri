class md_monitor;

  string name;                  
  // CAMBIO: Se califica la interfaz virtual con el modport 'Monitor'
  virtual md_interface.Monitor vif;     
  mailbox #(md_packet) mon_mbx; 

  // CAMBIO: El constructor ahora espera un handle del tipo correcto
  function new(string name, virtual md_interface.Monitor vif, mailbox #(md_packet) mon_mbx);
    this.name = name;
    this.vif = vif;
    this.mon_mbx = mon_mbx;
  endfunction

  task run();
    $display("[%s] El monitor ha comenzado a observar la interfaz.", name);
    
    forever begin
      // CAMBIO: Se reemplaza 'tb_cb' por 'mon_cb' en toda la tarea
      @(vif.mon_cb);

      if (vif.mon_cb.valid && vif.mon_cb.ready) begin
        md_packet pkt = new();
        pkt.data   = vif.mon_cb.data;
        pkt.offset = vif.mon_cb.offset;
        pkt.size   = vif.mon_cb.size;
        
        mon_mbx.put(pkt);
        
        $display("[%s] Transacción Capturada: data=%h, size=%d, offset=%d", 
                 name, pkt.data, pkt.size, pkt.offset);
      end
    end
  endtask

endclass