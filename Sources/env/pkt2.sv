class pkt2; // paquete que el driver recibe para generar paquetes MD (RX hacia DUT)
// Tiempos entre paquetes (ns)
rand int unsigned inter_pkt_time_ns;
// con/sin ventana (ventana: agrupa varios paquetes)
rand bit with_window;
// Datos de entrada - para simplificar un arreglo de palabras
rand bit [31:0] data[]; // tamaño variable
// cada entrada tiene size y offset asociados (arrays paralelos)
rand bit [2:0] size[]; // encodings aceptados: 1,2,4 (bytes)
rand bit [1:0] offset[]; // 0..3


function void post_randomize();
// garantizar coherencia tamaño/arrays
if (data.size() == 0) begin
data = new[1];
size = new[1];
offset = new[1];
data[0] = $urandom();
size[0] = 3'd4; // default 4
offset[0] = 2'd0;
end
endfunction


// constraints helper (user may set desired length before randomize)
constraint c_sizes {
foreach (size[i]) size[i] inside {3'd1, 3'd2, 3'd4};
foreach (offset[i]) offset[i] inside {[0:3]};
inter_pkt_time_ns inside {[0:10000]}; // 0ns..10us
}


function new(); endfunction
endclass