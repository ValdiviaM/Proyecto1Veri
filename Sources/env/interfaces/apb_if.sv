interface apb_if #(parameter ADDR_WIDTH = 16, DATA_WIDTH = 32);
  logic pclk;
  logic reset_n;
  logic [ADDR_WIDTH-1:0] paddr;
  logic pwrite;
  logic psel;
  logic penable;
  logic [DATA_WIDTH-1:0] pwdata;
  logic pready;
  logic [DATA_WIDTH-1:0] prdata;
  logic pslverr;

  clocking master_cb @(posedge pclk);
    default input #1step output #0;
    output paddr, pwrite, psel, penable, pwdata;
    input  pready, prdata, pslverr;
  endclocking

  modport DUT (
    input pclk, reset_n, paddr, pwrite, psel, penable, pwdata,
    output pready, prdata, pslverr
  );

  modport Transactor (
    clocking master_cb,
    input pclk,
    output reset_n
  );

  // NEW: For monitors (read-only access)
  modport Monitor (
    input pclk, reset_n, paddr, pwrite, psel, penable, pwdata,
          pready, prdata, pslverr
  );
endinterface
