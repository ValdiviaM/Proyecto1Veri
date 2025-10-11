// pkt3.sv
class pkt3;
  // General info
  rand int id;
  rand int delay_cycles;       // time between packets
  rand bit window_enable;      // with/without window

  // MD interface (data path)
  rand bit [31:0] data_in;
  rand int size;
  rand int offset;

  // APB interface (register transactions)
  rand bit [15:0] addr;
  rand bit [31:0] wdata;
  bit [31:0] rdata;
  rand bit write_en;

  // Output observation (driver returns)
  bit [31:0] data_out;
  bit [15:0] status_reg;
  bit        err_flag;

  function void display(string prefix="");
    $display("%sPKT[id=%0d] size=%0d offset=%0d data_in=0x%h addr=0x%h wdata=0x%h write=%b",
             prefix, id, size, offset, data_in, addr, wdata, write_en);
  endfunction
endclass
