interface apb_interface #(
    parameter APB_ADDR_WIDTH = 16,
    parameter APB_DATA_WIDTH = 32
);

  logic                           clk;
  logic                           reset_n;
  logic [APB_ADDR_WIDTH-1:0]    paddr;
  logic                           pwrite;
  logic                           psel;
  logic                           penable;
  logic [APB_DATA_WIDTH-1:0]    pwdata;
  logic                           pready;
  logic [APB_DATA_WIDTH-1:0]    prdata;
  logic                           pslverr;

  // --- Clocking Block para el DRIVER (Activo) ---
  // Define qué señales el Driver ESCRIBE (output) y LEE (input)
  clocking drv_cb @(posedge clk);
    default input #1step output #2;
    output paddr, pwrite, psel, penable, pwdata;
    input  pready, prdata, pslverr;
  endclocking

  // --- Clocking Block para el MONITOR (Pasivo) ---
  // Define que el Monitor SOLO LEE (todas son input)
  clocking mon_cb @(posedge clk);
    default input #1step;
    input paddr, pwrite, psel, penable, pwdata, pready, prdata, pslverr;
  endclocking

  // --- Modports (Conectores) ---

  // Para el DUT
  modport DUT (
    input  clk, reset_n, paddr, pwrite, psel, penable, pwdata,
    output pready, prdata, pslverr
  );
  
  // Para el Driver: le da acceso al clocking block de DRIVER
  modport Driver (
    clocking drv_cb,
    input clk, reset_n
  );

  // Para el Monitor: le da acceso al clocking block de MONITOR
  modport Monitor (
    clocking mon_cb,
    input clk, reset_n
  );

endinterface