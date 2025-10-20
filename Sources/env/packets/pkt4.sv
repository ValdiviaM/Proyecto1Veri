  class pkt4;
    rand bit [31:0] data;
    rand bit [2:0]  size;
    rand bit [1:0]  offset;

    function new();
    endfunction
    
    // This function was empty and unused. It can be removed or implemented if needed later.
    function void set_aligment(bit[2:0] s, bit[1:0] o);
        this.size = s;
        this.offset = o;
    endfunction
  endclass