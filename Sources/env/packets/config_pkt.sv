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

endpackage