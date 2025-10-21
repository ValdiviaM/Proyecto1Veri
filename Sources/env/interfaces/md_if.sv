interface md_interface #(
    parameter ALGN_DATA_WIDTH = 32
);

  localparam int unsigned ALGN_OFFSET_WIDTH = (ALGN_DATA_WIDTH <= 8) ? 1 : $clog2(ALGN_DATA_WIDTH/8);
  localparam int unsigned ALGN_SIZE_WIDTH   = $clog2(ALGN_DATA_WIDTH/8)+1;

  logic                        clk;
  logic                        reset_n;
  logic                        valid;
  logic [ALGN_DATA_WIDTH-1:0]  data;
  logic [ALGN_OFFSET_WIDTH-1:0] offset;
  logic [ALGN_SIZE_WIDTH-1:0]  size;
  logic                        ready;
  logic                        err;

  // --- Clocking Block para el DRIVER (Activo) ---
  clocking drv_cb @(posedge clk);
    default input #1step output #2;
    output valid, data, offset, size, err;
    input  ready;
  endclocking

  // --- Clocking Block para el MONITOR (Pasivo) ---
  clocking mon_cb @(posedge clk);
    default input #1step;
    // El monitor solo lee, por lo que todo es 'input'
    input valid, data, offset, size, err, ready;
  endclocking

  // --- Modports (Conectores) ---

  // Modport para el Driver (Master)
  modport Master (
    clocking drv_cb, // <-- CAMBIO: Exporta el clocking block
    input clk, reset_n
  );

  // Modport para el DUT (Slave)
  modport Slave (
    input  valid, data, offset, size, err, clk, reset_n,
    output ready
  );

  // Modport para el Monitor pasivo
  modport Monitor (
    clocking mon_cb, // <-- CAMBIO: Exporta el clocking block
    input clk, reset_n
  );

endinterface