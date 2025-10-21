//
// Archivo: md_driver.sv
// Descripción: Driver para el bus de datos MD.
//              Toma transacciones 'md_packet' de un mailbox y las conduce
//              sobre una interfaz MD virtual.
//

class md_driver;

  string name = "MD_Driver";
  // CAMBIO: Se califica la interfaz virtual con el modport 'Master'
  virtual md_interface.Master vif;     
  mailbox #(md_packet) drv_mbx; 

  // CAMBIO: El constructor ahora espera un handle del tipo correcto
  function new(virtual md_interface.Master vif, mailbox #(md_packet) drv_mbx);
    this.vif = vif;
    this.drv_mbx = drv_mbx;
  endfunction

  task run();
    $display("[%s] El driver ha comenzado.", name);
    reset_signals();
    forever begin
      md_packet pkt;
      drv_mbx.get(pkt);
      $display("[%s] Recibido paquete del generador. Conduciendo a la interfaz...", name);
      drive_packet(pkt);
      if (pkt.delay_cycles > 0) begin
        $display("[%s] Esperando %0d ciclos de retardo.", name, pkt.delay_cycles);
        // CAMBIO: Se usa el clocking block correcto
        repeat(pkt.delay_cycles) @(vif.drv_cb);
      end
    end
  endtask

  protected task drive_packet(md_packet pkt);
    // CAMBIO: Se reemplaza 'tb_cb' por 'drv_cb' en toda la tarea
    @(vif.drv_cb);
    vif.drv_cb.valid  <= 1'b1;
    vif.drv_cb.data   <= pkt.data;
    vif.drv_cb.offset <= pkt.offset;
    vif.drv_cb.size   <= pkt.size;
    
    while (!vif.drv_cb.ready) begin
      @(vif.drv_cb);
    end
    
    @(vif.drv_cb);
    reset_signals();
    $display("[%s] Paquete enviado exitosamente.", name);
  endtask

  protected task reset_signals();
    // CAMBIO: Se reemplaza 'tb_cb' por 'drv_cb'
    vif.drv_cb.valid  <= 1'b0;
    vif.drv_cb.data   <= 'x;
    vif.drv_cb.offset <= 'x;
    vif.drv_cb.size   <= 'x;
  endtask

endclass