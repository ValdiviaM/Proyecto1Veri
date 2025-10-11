interface apb_if #(parameter ADDR_WIDTH = 16, DATA_WIDTH = 32);

  // APB Signals
  logic [ADDR_WIDTH-1:0] paddr;
  logic                  pwrite;
  logic                  psel;
  logic                  penable;
  logic [DATA_WIDTH-1:0] pwdata;
  logic                  pready;
  logic [DATA_WIDTH-1:0] prdata;
  logic                  pslverr;

  // Modports for DUT and TB sides
  modport DUT (
    input  paddr,
    input  pwrite,
    input  psel,
    input  penable,
    input  pwdata,
    output pready,
    output prdata,
    output pslverr
  );

  modport Transactor (
    output paddr,
    output pwrite,
    output psel,
    output penable,
    output pwdata,
    input  pready,
    input  prdata,
    input  pslverr
  );

endinterface
