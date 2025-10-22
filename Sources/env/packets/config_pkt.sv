package dut_params_pkg;

  // --- Anchos de datos y offsets ---
  parameter int unsigned ALGN_DATA_WIDTH    = 32;
  parameter int unsigned ALGN_OFFSET_WIDTH  = $clog2(ALGN_DATA_WIDTH/8);
  parameter int unsigned ALGN_SIZE_WIDTH    = $clog2(ALGN_DATA_WIDTH/8) + 1;

  // --- Direcciones base APB ---
  parameter int unsigned ADDR_CTRL   = 'h00;
  parameter int unsigned ADDR_STATUS = 'h04;

  // --- Campos de los registros CTRL ---
  parameter int unsigned LSB_CTRL_SIZE   = 0;
  parameter int unsigned LSB_CTRL_OFFSET = 8;
  parameter int unsigned LSB_CTRL_CLR    = 16;

  // --- Campos del STATUS ---
  parameter int unsigned LSB_STATUS_CNT_DROP   = 0;
  parameter int unsigned STATUS_CNT_DROP_WIDTH = 8;
  parameter int unsigned LSB_STATUS_RX_LVL = 8;
  parameter int unsigned STATUS_RX_LVL_WIDTH = 4;
  parameter int unsigned LSB_STATUS_TX_LVL = 16;
  parameter int unsigned STATUS_TX_LVL_WIDTH = 4;


    // --- Espacios del registro IRQEN  ---
  parameter int unsigned LSB_IRQEN_RX_FIFO_EMPTY = 0;
  parameter int unsigned LSB_IRQEN_RX_FIFO_FULL  = 1;
  parameter int unsigned LSB_IRQEN_TX_FIFO_EMPTY = 2;
  parameter int unsigned LSB_IRQEN_TX_FIFO_FULL  = 3;
  parameter int unsigned LSB_IRQEN_MAX_DROP      = 4;
  
  // --- Espacios del registro IRQ ---
  parameter int unsigned LSB_IRQ_RX_FIFO_EMPTY = 0;
  parameter int unsigned LSB_IRQ_RX_FIFO_FULL  = 1;
  parameter int unsigned LSB_IRQ_TX_FIFO_EMPTY = 2;
  parameter int unsigned LSB_IRQ_TX_FIFO_FULL  = 3;
  parameter int unsigned LSB_IRQ_MAX_DROP      = 4;
  
endpackage