class md_packet;

  // Parámetros del bus (deben coincidir con la instanciación del DUT)
  localparam ALGN_DATA_WIDTH = 32;
  localparam ALGN_OFFSET_WIDTH = (ALGN_DATA_WIDTH <= 8) ? 1 : $clog2(ALGN_DATA_WIDTH/8);
  localparam ALGN_SIZE_WIDTH   = $clog2(ALGN_DATA_WIDTH/8)+1;

  //--------------- Variables Aleatorias (Campos del Bus) ---------------//
  rand bit [ALGN_DATA_WIDTH-1:0]   data;
  rand bit [ALGN_OFFSET_WIDTH-1:0] offset;
  rand bit [ALGN_SIZE_WIDTH-1:0]   size;

  //--------------- Variables de Control para el Test ---------------//
  rand int unsigned  delay_cycles; 
  rand bit           is_legal;
  
  //--- NUEVA VARIABLE DE AYUDA para controlar la distribución ---//
  rand int unsigned  legality_weight;

  //--------------- Restricciones de Aleatorización ---------------//

  constraint c_delay_range { 
    delay_cycles inside {[0:50]}; 
  }

  constraint c_legal_packet {
    is_legal == 1 -> {
      size > 0;
      size <= (ALGN_DATA_WIDTH / 8);
      (((ALGN_DATA_WIDTH / 8) + offset) % size) == 0;
    }
  }

  constraint c_illegal_packet {
    is_legal == 0 -> {
      (size == 0) || ((((ALGN_DATA_WIDTH / 8) + offset) % size) != 0);
    }
  }

  //--- REEMPLAZO para la restricción 'dist' ---//
  // 1. Restringimos el peso a un rango de 100 valores (0-99)
  constraint c_legality_weight_range {
    legality_weight inside {[0:99]};
  }
  // 2. Relacionamos 'is_legal' con el peso. Si el peso es menor que 90 (90 de 100 posibilidades),
  //    entonces 'is_legal' es verdadero. De lo contrario, es falso.
  constraint c_legality_distribution {
    (legality_weight < 90) -> (is_legal == 1);
    (legality_weight >= 90) -> (is_legal == 0);
  }
  
  //--------------- Métodos Utilitarios ---------------//
  
  function string display(string name = "md_packet");
    return $sformatf("[%s] data=%h, size=%d, offset=%d, delay=%d, legal=%b",
                     name, data, size, offset, delay_cycles, is_legal);
  endfunction

endclass