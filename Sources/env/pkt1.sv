class pkt1; // paquete que recibe el DUT desde el Test (config inicial)
rand int unsigned n_transactions; // numero de transacciones a generar
// registros de configuracion (ejemplo): control/status/offset_control
rand bit [31:0] cfg_control;
rand bit [31:0] cfg_status;
rand bit [31:0] cfg_offset_ctrl; // ejemplo
// Profundidades de FIFO
rand int unsigned fifo_rx_depth; // profundidad FIFO RX
rand int unsigned fifo_tx_depth; // profundidad FIFO TX


constraint c_ranges {
n_transactions inside {[1:1024]};
fifo_rx_depth inside {[1:256]};
fifo_tx_depth inside {[1:256]};
// control/status defaults razonables
cfg_control inside {[0:32'hFFFF_FFFF]};
cfg_status inside {[0:32'hFFFF_FFFF]};
cfg_offset_ctrl inside {[0:32'hFFFF_FFFF]};
}


function new(); endfunction
endclass