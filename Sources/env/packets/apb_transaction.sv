//
// Archivo: apb_transaction.sv
// Descripción: Define una transacción para el bus APB (lectura o escritura).
//
// Definimos las direcciones de los registros del DUT para usarlas en las restricciones
`define ADDR_CTRL   'h0000
`define ADDR_STATUS 'h000c
`define ADDR_IRQEN  'h00f0
`define ADDR_IRQ    'h00f4

typedef enum { APB_READ, APB_WRITE } apb_op_e;

class apb_transaction;

  // Parámetros del bus
  localparam APB_ADDR_WIDTH = 16;
  localparam APB_DATA_WIDTH = 32;

  //--------------- Variables Aleatorias ---------------//
  rand apb_op_e                  op;     // Tipo de operación: LECTURA o ESCRITURA
  rand bit [APB_ADDR_WIDTH-1:0]  addr;   // Dirección del registro
  rand bit [APB_DATA_WIDTH-1:0]  wdata;  // Datos a escribir (solo para escrituras)

  //--------------- Variables de Resultado ---------------//
  bit [APB_DATA_WIDTH-1:0]       rdata;  // Datos leídos (solo para lecturas)
  bit                           slverr; // Estado de error del esclavo
  bit 				error;
  //--------------- Restricciones de Aleatorización ---------------//

  // Restringe las operaciones a las direcciones válidas del DUT
  constraint c_valid_addresses {
    addr inside { `ADDR_CTRL, `ADDR_STATUS, `ADDR_IRQEN, `ADDR_IRQ };
  }
  
  // Restringe el tipo de operación por registro.
  // El registro de STATUS es de solo lectura.
  constraint c_readonly_regs {
      addr == `ADDR_STATUS -> op == APB_READ;
  }
  
  // Función para imprimir el contenido de la transacción
  function string display(string name = "apb_transaction");
      string s = $sformatf("[%s] op=%s, addr=%h", name, op.name(), addr);
    if (op == APB_WRITE) begin
      s = {s, $sformatf(", wdata=0x%h", wdata)};
    end else begin
      s = {s, $sformatf(", rdata=0x%h", rdata)};
    end
    
    if (slverr || error) begin
      s = {s, " [ERROR]"};
    end

    return s;
    
  endfunction

endclass
