class pkt6;
  int id;                    // identificador único del paquete
  bit [31:0] data[];         // datos esperados de salida
  bit [2:0] size[];          // tamaño esperado de cada word
  bit [1:0] offset[];        // offset esperado de cada word

  // Constructor
  function new();
    id     = 0;
    data   = new[0];
    size   = new[0];
    offset = new[0];
  endfunction
endclass
