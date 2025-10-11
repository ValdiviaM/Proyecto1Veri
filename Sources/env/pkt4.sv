class pkt4;
// - Combinaciones de alineamiento valido
  typedef enum bit [2:0] {
    ALIGN_1B_OFF0,  // SIZE=1, OFFSET=0
    ALIGN_1B_OFF1,  // SIZE=1, OFFSET=1
    ALIGN_1B_OFF2,  // SIZE=1, OFFSET=2
    ALIGN_1B_OFF3,  // SIZE=1, OFFSET=3
    ALIGN_2B_OFF0,  // SIZE=2, OFFSET=0
    ALIGN_2B_OFF2,  // SIZE=2, OFFSET=2
    ALIGN_4B_OFF0   // SIZE=4, OFFSET=0
  } alignment_type_e;

// - Interrupciones (IRQ)
  typedef enum bit [4:0] {
    IRQ_RX_FIFO_EMPTY = 5'b00001,
    IRQ_RX_FIFO_FULL  = 5'b00010,
    IRQ_TX_FIFO_EMPTY = 5'b00100,
    IRQ_TX_FIFO_FULL  = 5'b01000,
    IRQ_MAX_DROP      = 5'b10000
  } irq_type_e;

//-Atributos (IRQ)
  
  rand bit [4:0] irq_status;         // Estado de las interrupciones
  rand bit [4:0] irq_enable;         // Habilitación de interrupciones
  bit            irq_out;            // Salida IRQ (OR de todas las habilitadas)
  
  bit            rx_fifo_empty_event;
  bit            rx_fifo_full_event;
  bit            tx_fifo_empty_event;
  bit            tx_fifo_full_event;
  bit            max_drop_event;


//-Atributos alineamiento
 rand alignment_type_e alignment_cfg;  // Configuración de alineamiento
 rand bit [1:0]        offset;         // CTRL.OFFSET
 rand bit [2:0]        size;           // CTRL.SIZE

//-Atributos contador de errores
  rand bit [7:0] cnt_drop;           // Valor del contador CNT_DROP
  bit            cnt_drop_max;       // Indica si alcanzó el máximo (255)
  bit            cnt_drop_cleared;   // Indica si fue limpiado vía CTRL.CLR


// Reset
  bit reset_active;
  bit reset_n;
  

//Constraints

// Contador de drops debe estar en rango válido
  constraint c_cnt_drop {
    cnt_drop <= 8'hFF;
  }

  // Configuración de alineamiento válida
  constraint c_alignment {
    if (alignment_cfg == ALIGN_1B_OFF0) {
      size == 3'd1; offset == 2'd0;
    }
    else if (alignment_cfg == ALIGN_1B_OFF1) {
      size == 3'd1; offset == 2'd1;
    }
    else if (alignment_cfg == ALIGN_1B_OFF2) {
      size == 3'd1; offset == 2'd2;
    }
    else if (alignment_cfg == ALIGN_1B_OFF3) {
      size == 3'd1; offset == 2'd3;
    }
    else if (alignment_cfg == ALIGN_2B_OFF0) {
      size == 3'd2; offset == 2'd0;
    }
    else if (alignment_cfg == ALIGN_2B_OFF2) {
      size == 3'd2; offset == 2'd2;
    }
    else if (alignment_cfg == ALIGN_4B_OFF0) {
      size == 3'd4; offset == 2'd0;
    }
  }


//-Constructor
  function new();
    this.cnt_drop = 0;
    this.cnt_drop_max = 0;
    this.cnt_drop_cleared = 0;
    this.irq_status = 5'b0;
    this.irq_enable = 5'b0;
    this.irq_out = 0;
  endfunction


//-Reset

//-Metodo (IRQ)

  function void update_irq_output();
    // IRQ output es OR de todas las interrupciones habilitadas
    irq_out = |(irq_status & irq_enable);
  endfunction

//-Metodo alineamiento
function void set_aligment(bit [2:0] new_size, bit [1:0] new_offset);
    size = new_size;
    offset = new_offset;

    case ({new_size, new_offset})
      {3'd1, 2'd0}: alignment_cfg = ALIGN_1B_OFF0;
      {3'd1, 2'd1}: alignment_cfg = ALIGN_1B_OFF1;
      {3'd1, 2'd2}: alignment_cfg = ALIGN_1B_OFF2;
      {3'd1, 2'd3}: alignment_cfg = ALIGN_1B_OFF3;
      {3'd2, 2'd0}: alignment_cfg = ALIGN_2B_OFF0;
      {3'd2, 2'd2}: alignment_cfg = ALIGN_2B_OFF2;
      {3'd4, 2'd0}: alignment_cfg = ALIGN_4B_OFF0;
      default:      alignment_cfg = ALIGN_4B_OFF0;
    endcase
endfunction

endclass