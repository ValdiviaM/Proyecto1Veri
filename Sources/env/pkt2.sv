// Clase base con temporización
class pkt_base;
  rand int unsigned inter_pkt_time_ns;
  constraint c_delay { inter_pkt_time_ns inside {[0:10000]}; }
endclass

// Paquete para el driver APB
class apb_pkt extends pkt_base;
  rand bit        write_en;
  rand bit [15:0] addr; // Coincide con ADDR_WIDTH del DUT
  rand bit [31:0] data;
endclass

// Paquete para el driver MD
class md_pkt extends pkt_base;
  rand int unsigned num_words = 1; // Para controlar el tamaño del paquete
  rand bit [31:0] data[];
  rand bit [2:0]  size[];
  rand bit [1:0]  offset[];

  constraint c_sizes {
    // Primero, restringir el número de palabras del paquete
    num_words inside {[1:16]}; // Por ejemplo, paquetes de 1 a 16 palabras
    
    // Forzar a los arreglos a tener el tamaño correcto
    data.size() == num_words;
    size.size() == num_words;
    offset.size() == num_words;

    // Restringir los valores de cada elemento
    foreach(size[i]) size[i] inside {3'd1, 3'd2, 3'd4};
  }

  constraint c_legal_combinations {
    foreach(data[i]) {
      // Un size de 2 bytes solo es válido en offsets pares
      (size[i] == 2) -> (offset[i] % 2 == 0);
      // Un size de 4 bytes solo es válido en offset 0
      (size[i] == 4) -> (offset[i] == 0);
    }
  }
endclass