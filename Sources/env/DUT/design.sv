
`ifndef CFS_SYNCH_V
  `define CFS_SYNCH_V

  module cfs_synch#(
    parameter DATA_WIDTH = 32
  ) (
    input                       clk,
    input     [DATA_WIDTH-1:0]  i,
    output reg[DATA_WIDTH-1:0]  o
  );

    always@(posedge clk) begin
      o <= i;
    end

  endmodule

`endif

`ifndef CFS_SYNCH_FIFO_V
  `define CFS_SYNCH_FIFO_V

  module cfs_synch_fifo #(
     parameter DATA_WIDTH = 32,
     parameter FIFO_DEPTH = 8,
     //Clock Domain Crossing
     //Set this parameter to 0 only if push_clk and pop_clk are tied to the same clock signal.
     parameter CDC        = 1,
    
    localparam CNT_WIDTH = $clog2(FIFO_DEPTH)
  ) (
    input                       reset_n,

    input                       push_clk,
    input                       push_valid,
    input[DATA_WIDTH-1:0]       push_data,
    output wire                 push_ready,

    //Full flag - in PUSH clock domain
    output wire                 push_full,

    //Empty flag - in PUSH clock domain
    output wire                 push_empty,
    
    //FIFO level - in PUSH clock domain
    output reg[CNT_WIDTH:0]     push_fifo_lvl,

    input                       pop_clk,
    output wire                 pop_valid,
    output wire[DATA_WIDTH-1:0] pop_data,
    input                       pop_ready,

    //Full flag - in POP clock domain
    output wire                 pop_full,

    //Empty flag - in POP clock domain
    output wire                 pop_empty,
    
    //FIFO level - in POP clock domain
    output reg[CNT_WIDTH:0]     pop_fifo_lvl
  );

    initial begin
      assert(DATA_WIDTH >= 1) else begin
        $error($sformatf("Legal values for DATA_WIDTH parameter must greater of equal than 1 but found 'd%0d", DATA_WIDTH));
      end

      assert(FIFO_DEPTH >= 1) else begin
        $error($sformatf("Legal values for FIFO_DEPTH parameter must greater of equal than 1 but found 'd%0d", FIFO_DEPTH));
      end
    end

    //Memory containing the FIFO information
    reg[DATA_WIDTH-1:0] fifo[0:FIFO_DEPTH-1];


    //Read pointer - in PUSH clock domain
    wire[CNT_WIDTH-1:0] rd_ptr_push;

    //Read pointer - in POP clock domain
    reg[CNT_WIDTH-1:0]  rd_ptr_pop;


    //Next write pointer - in PUSH clock domain
    reg[CNT_WIDTH-1:0] next_wr_ptr_push;

    //Next read pointer - in POP clock domain
    reg[CNT_WIDTH-1:0] next_rd_ptr_pop;

    //Write pointer - in PUSH clock domain
    reg[CNT_WIDTH-1:0] wr_ptr_push;

    //Write pointer - in POP clock domain
    wire[CNT_WIDTH-1:0] wr_ptr_pop;

    //FIFO level - in PUSH clock domain, delayed
    reg[CNT_WIDTH:0] push_fifo_lvl_dly;

    //FIFO level - in POP clock domain, delayed
    reg[CNT_WIDTH:0] pop_fifo_lvl_dly;

    always_comb begin
      if(wr_ptr_push == FIFO_DEPTH - 1) begin
        next_wr_ptr_push = 0;
      end
      else begin
        next_wr_ptr_push = wr_ptr_push + 1;
      end
    end
    
    always@(posedge push_clk or negedge reset_n) begin
      if(reset_n == 0) begin
        push_fifo_lvl_dly  <= 0;
      end
      else begin
        push_fifo_lvl_dly <= push_fifo_lvl;
      end
    end
    
    always@(posedge pop_clk or negedge reset_n) begin
      if(reset_n == 0) begin
        pop_fifo_lvl_dly  <= 0;
      end
      else begin
        pop_fifo_lvl_dly <= pop_fifo_lvl;
      end
    end
    
    assign push_empty = (push_fifo_lvl == 0);
    assign push_full  = (push_fifo_lvl == FIFO_DEPTH);
    
    always@(posedge push_clk or negedge reset_n) begin
      if(reset_n == 0) begin
        wr_ptr_push <= 0;
      end
      else begin
        if(push_valid & push_ready) begin
          fifo[wr_ptr_push] <= push_data;
          wr_ptr_push       <= next_wr_ptr_push;
        end
      end
    end

    assign push_ready = push_valid & !push_full;

    always_comb begin
      if(rd_ptr_pop == FIFO_DEPTH - 1) begin
        next_rd_ptr_pop = 0;
      end
      else begin
        next_rd_ptr_pop = rd_ptr_pop + 1;
      end
    end

    assign pop_empty = (pop_fifo_lvl == 0);
    assign pop_full  = (pop_fifo_lvl == FIFO_DEPTH);
    
    always@(posedge pop_clk or negedge reset_n) begin
      if(reset_n == 0) begin
        rd_ptr_pop <= 0;
      end
      else begin
        if(pop_valid & pop_ready) begin
          rd_ptr_pop <= next_rd_ptr_pop;
        end
      end
    end
    
    always_comb begin
      if(wr_ptr_push == rd_ptr_push) begin
        if(push_fifo_lvl_dly >= FIFO_DEPTH - 1) begin
          push_fifo_lvl = FIFO_DEPTH;
        end
        else begin
          push_fifo_lvl = 0;
        end
      end
      else if(wr_ptr_push > rd_ptr_push) begin
        push_fifo_lvl = wr_ptr_push - rd_ptr_push;
      end
      else begin
        push_fifo_lvl = FIFO_DEPTH - (rd_ptr_push - wr_ptr_push);
      end
    end

    always_comb begin
      if(wr_ptr_pop == rd_ptr_pop) begin
        if(pop_fifo_lvl_dly >= FIFO_DEPTH - 1) begin
          pop_fifo_lvl = FIFO_DEPTH;
        end
        else begin
          pop_fifo_lvl = 0;
        end
      end
      else if(wr_ptr_pop > rd_ptr_pop) begin
        pop_fifo_lvl = wr_ptr_pop - rd_ptr_pop;
      end
      else begin
        pop_fifo_lvl = FIFO_DEPTH - (rd_ptr_pop - wr_ptr_pop);
      end
    end

    assign pop_valid = !pop_empty;
    assign pop_data  = fifo[rd_ptr_pop];

    if(CDC == 1) begin
      //Synchronizer to move the wr_ptr information from PUSH clock domain to POP clock domain
      cfs_synch#(CNT_WIDTH) synch_wr_ptr_push2pop(
        .clk(pop_clk),
        .i(wr_ptr_push),
        .o(wr_ptr_pop)
      );

      //Synchronizer to move the rd_ptr information from POP clock domain to PUSH clock domain
      cfs_synch#(CNT_WIDTH) synch_rd_ptr_pop2push(
        .clk(push_clk),
        .i(rd_ptr_pop),
        .o(rd_ptr_push)
      );
    end
    else begin
       assign wr_ptr_pop  = wr_ptr_push;
       assign rd_ptr_push = rd_ptr_pop;
    end

  endmodule

`endif

`ifndef CFS_RX_CTRL_V
  `define CFS_RX_CTRL_V

  module cfs_rx_ctrl #(
    parameter ALGN_DATA_WIDTH       = 32,
    parameter STATUS_CNT_DROP_WIDTH = 8,

    localparam int unsigned ALGN_OFFSET_WIDTH = ALGN_DATA_WIDTH <= 8 ? 1 : $clog2(ALGN_DATA_WIDTH/8),
    localparam int unsigned ALGN_SIZE_WIDTH   = $clog2(ALGN_DATA_WIDTH/8)+1,
    localparam int unsigned FIFO_DATA_WIDTH   = ALGN_DATA_WIDTH + ALGN_OFFSET_WIDTH + ALGN_SIZE_WIDTH
  )(
    input                                  preset_n,
    input                                  pclk,

    input                                  clr_cnt_dop,

    output wire[STATUS_CNT_DROP_WIDTH-1:0] status_cnt_drop,

    input                                  md_rx_clk,
    input                                  md_rx_valid,
    input[ALGN_DATA_WIDTH-1:0]             md_rx_data,
    input[ALGN_OFFSET_WIDTH-1:0]           md_rx_offset,
    input[ALGN_SIZE_WIDTH-1:0]             md_rx_size,
    output wire                            md_rx_ready,
    output reg                             md_rx_err,

    output wire                            push_valid,
    output wire[FIFO_DATA_WIDTH-1:0]       push_data,
    input                                  push_ready,

    input                                  rx_fifo_full
    );

    localparam int unsigned DATA_MSB = ALGN_DATA_WIDTH-1;
    localparam int unsigned DATA_LSB = 0;
    
    localparam int unsigned OFFSET_MSB = ALGN_DATA_WIDTH+ALGN_OFFSET_WIDTH-1;
    localparam int unsigned OFFSET_LSB = ALGN_DATA_WIDTH;
    
    localparam int unsigned SIZE_MSB = ALGN_DATA_WIDTH+ALGN_OFFSET_WIDTH+ALGN_SIZE_WIDTH-1;
    localparam int unsigned SIZE_LSB = ALGN_DATA_WIDTH+ALGN_OFFSET_WIDTH;
    
    //STATUS.CNT_DROP in the md_rx_clk domain
    reg[STATUS_CNT_DROP_WIDTH-1:0] md_rx_clk_status_cnt_drop;

    //Synchronizer to move the STATUS.CNT_DROP information from md_rx_clk clock domain to pclk clock domain
    cfs_synch#(STATUS_CNT_DROP_WIDTH) synch_status_cnt_drop(
      .clk(pclk),
      .i  (md_rx_clk_status_cnt_drop),
      .o  (status_cnt_drop)
    );

    always@(posedge md_rx_clk or negedge preset_n or posedge clr_cnt_dop) begin
      if(!preset_n | clr_cnt_dop) begin
        md_rx_clk_status_cnt_drop <= 0;
      end
      else begin
        if(md_rx_valid & md_rx_ready & md_rx_err) begin
          if(md_rx_clk_status_cnt_drop < (('h1 << STATUS_CNT_DROP_WIDTH) - 1)) begin
            md_rx_clk_status_cnt_drop <= md_rx_clk_status_cnt_drop + 1;
          end
        end
      end
    end

    always_comb begin
      if(md_rx_valid == 1) begin
        if(md_rx_size == 0) begin
          md_rx_err = 1;
        end
        else if((((ALGN_DATA_WIDTH / 8) + md_rx_offset) % md_rx_size) != 0) begin
          md_rx_err = 1;
        end
        else begin
          md_rx_err = 0;
        end
      end
      else begin
        md_rx_err = 0;
      end
    end

    assign md_rx_ready = (push_valid & push_ready) | md_rx_err;

    assign push_valid = md_rx_valid & !md_rx_err;

    assign push_data[SIZE_MSB  :SIZE_LSB]   = md_rx_size;
    assign push_data[OFFSET_MSB:OFFSET_LSB] = md_rx_offset;
    assign push_data[DATA_MSB  :DATA_LSB]   = md_rx_data;

  endmodule

`endif

`ifndef CFS_CTRL_V
  `define CFS_CTRL_V

  module cfs_ctrl #(
    parameter ALGN_DATA_WIDTH = 32,

    localparam int unsigned ALGN_OFFSET_WIDTH = ALGN_DATA_WIDTH <= 8 ? 1 : $clog2(ALGN_DATA_WIDTH/8),
    localparam int unsigned ALGN_SIZE_WIDTH   = $clog2(ALGN_DATA_WIDTH/8)+1,
    localparam int unsigned FIFO_WIDTH        = ALGN_DATA_WIDTH + ALGN_OFFSET_WIDTH + ALGN_SIZE_WIDTH
  )(
    
    input                        reset_n,
    input                        clk,

    input                        pop_valid,
    input[FIFO_WIDTH-1:0]        pop_data,
    output reg                   pop_ready,

    output reg                   push_valid,
    output reg[FIFO_WIDTH-1:0]   push_data,
    input                        push_ready,
    
    input[ALGN_OFFSET_WIDTH-1:0] ctrl_offset,
    input[ALGN_SIZE_WIDTH-1:0]   ctrl_size
    );
    
    localparam int unsigned DATA_MSB = ALGN_DATA_WIDTH-1;
    localparam int unsigned DATA_LSB = 0;
    
    localparam int unsigned OFFSET_MSB = ALGN_DATA_WIDTH+ALGN_OFFSET_WIDTH-1;
    localparam int unsigned OFFSET_LSB = ALGN_DATA_WIDTH;
    
    localparam int unsigned SIZE_MSB = ALGN_DATA_WIDTH+ALGN_OFFSET_WIDTH+ALGN_SIZE_WIDTH-1;
    localparam int unsigned SIZE_LSB = ALGN_DATA_WIDTH+ALGN_OFFSET_WIDTH;
    
    //Current offset to be aligned
    reg[ALGN_OFFSET_WIDTH-1:0] unaligned_offset;
    
    //Current size to be aligned
    reg[ALGN_SIZE_WIDTH-1:0] unaligned_size;
    
    //Current data to be aligned
    reg[ALGN_DATA_WIDTH-1:0] unaligned_data;
    
    //Current number of bytes from the unaligned data which were already processed
    reg[ALGN_SIZE_WIDTH-1:0] unaligned_bytes_processed;
    
    //Current number of bytes in the aligned data so far
    reg[ALGN_SIZE_WIDTH-1:0] aligned_bytes_processed;
    
    always@(posedge clk or negedge reset_n) begin
      if(reset_n == 0) begin
        pop_ready                 <= 1;
        
        push_valid                <= 0;
        push_data                 <= 0;
        
        unaligned_offset          <= 0;
        unaligned_size            <= 0;
        unaligned_data            <= 0;
        unaligned_bytes_processed <= 0;
        
        aligned_bytes_processed   <= 0;
      end
      else begin
        if((push_valid == 1) & (push_ready == 0)) begin
          //Aligned data is waiting to be accepted
          
          if(unaligned_bytes_processed >= unaligned_size) begin
            //All the buffered unaligned bytes were processed - try to take new ones
            
            if((pop_valid == 1) && (pop_ready == 1)) begin
              //Transfer the unaligned data to the internal buffer
              
              pop_ready                 <= 0;
              
              unaligned_offset          <= pop_data[OFFSET_MSB:OFFSET_LSB];
              unaligned_size            <= pop_data[SIZE_MSB:SIZE_LSB];
              unaligned_data            <= pop_data[DATA_MSB:DATA_LSB];
              unaligned_bytes_processed <= 0;
        
            end
            else if((pop_valid == 1) && (pop_ready == 0)) begin
              //Accept the unaligned data
              
              pop_ready <= 1;
            end
            else begin
              //Already accept the future unaligned data which will come
              
              pop_ready <= 1;
            end
          end
          else begin
            //There is no room to save any incomming unaligned data, so stop the flow
            
            pop_ready <= 0;
          end
          
        end
        else if((push_valid == 1) & (push_ready == 1)) begin
          //Aligned data was accepted
          
          if(unaligned_bytes_processed >= unaligned_size) begin
            //All the buffered unaligned bytes were processed
            
            if((pop_valid == 1) && (pop_ready == 1)) begin
              //Incomming unaligned bytes are ready to be processed
              
              if(pop_data[SIZE_MSB:SIZE_LSB] >= ctrl_size) begin
                //There is enough information on the incomming unaligned bytes to aligned it
                
                push_valid                       <= 1;
                push_data[DATA_MSB:DATA_LSB]     <= ((('h1 << (ctrl_size * 8)) - 1) & (pop_data[DATA_MSB:DATA_LSB] >> (pop_data[OFFSET_MSB:OFFSET_LSB] * 8))) << (8 * ctrl_offset);
                push_data[SIZE_MSB:SIZE_LSB]     <= ctrl_size;
                push_data[OFFSET_MSB:OFFSET_LSB] <= ctrl_offset;
                
                unaligned_offset                 <= pop_data[OFFSET_MSB:OFFSET_LSB];
                unaligned_size                   <= pop_data[SIZE_MSB:SIZE_LSB];
                unaligned_data                   <= pop_data[DATA_MSB:DATA_LSB];
                unaligned_bytes_processed        <= ctrl_size;
                aligned_bytes_processed          <= 0;
                
                if(pop_data[SIZE_MSB:SIZE_LSB] > ctrl_size) begin
                  //There is too much data in the incomming unaligned packet. Stop the reception
                  //to have time to align it all.
                  pop_ready <= 0;
                end
                else begin
                  pop_ready <= 1;
                end
              end
              else begin
                //There is no enough information on the incomming unaligned bytes to aligned it - just prepare what is available for alignment
                
                push_valid              <= 0;
                push_data               <= ((('h1 << (pop_data[SIZE_MSB:SIZE_LSB] * 8)) - 1) & (pop_data[DATA_MSB:DATA_LSB] >> (pop_data[OFFSET_MSB:OFFSET_LSB] * 8))) << (8 * ctrl_offset);
                aligned_bytes_processed <= pop_data[SIZE_MSB:SIZE_LSB];
              end
            end
            else if((pop_valid == 1) && (pop_ready == 0)) begin
              //There is a request to get incomming unaligned data so accept it
              
              pop_ready               <= 1;
              push_valid              <= 0;
              push_data               <= 0;
              aligned_bytes_processed <= 0;
            end
            else begin
              //Already accept the future unaligned data which will come
              
              pop_ready               <= 1;
              push_valid              <= 0;
              push_data               <= 0;
              aligned_bytes_processed <= 0;
            end
          end
          else begin
            //There is still some unaligned bytes not processed
            
            if((unaligned_size - unaligned_bytes_processed) >= ctrl_size) begin
              //There is enough information on the buffered unaligned bytes to aligned it
              
              push_valid                       <= 1;
              push_data[DATA_MSB:DATA_LSB]     <= ((('h1 << (ctrl_size * 8)) - 1) & (unaligned_data >> ((unaligned_offset + unaligned_bytes_processed) * 8))) << (8 * ctrl_offset);
              push_data[SIZE_MSB:SIZE_LSB]     <= ctrl_size;
              push_data[OFFSET_MSB:OFFSET_LSB] <= ctrl_offset;
              unaligned_bytes_processed        <= unaligned_bytes_processed + ctrl_size;
              aligned_bytes_processed          <= 0;
              
              if(unaligned_bytes_processed + ctrl_size >= unaligned_size) begin
                //The buffered unaligned data was completly processed, get ready for new incomming unaligned data
                
                pop_ready <= 1;
              end
            end
            else begin
              //There is no enough information on the buffered unaligned bytes to aligned it - just prepare what is available for alignment
              
              push_valid                <= 0;
              push_data                 <= ((('h1 << ((unaligned_size - unaligned_bytes_processed) * 8)) - 1) & (unaligned_data >> ((unaligned_offset + unaligned_bytes_processed) * 8))) << (8 * ctrl_offset);
              unaligned_bytes_processed <= unaligned_size;
              aligned_bytes_processed   <= unaligned_size - unaligned_bytes_processed;
              
              //Already accept any incomming unaligned data
              pop_ready <= 1;
            end
          end
        end
        else begin
          //There is no aligned data sent so far
          
          if(unaligned_bytes_processed >= unaligned_size) begin
            //All the buffered unaligned bytes were processed
            
            if((pop_valid == 1) && (pop_ready == 1)) begin
              if(pop_data[SIZE_MSB:SIZE_LSB] >= (ctrl_size - aligned_bytes_processed)) begin
                //There is enough information in the incomming unaligned data to send an aligned packet
                
                push_valid                       <= 1;
                push_data[DATA_MSB:DATA_LSB]     <= push_data[DATA_MSB:DATA_LSB] | (((('h1 << ((ctrl_size - aligned_bytes_processed) * 8)) - 1) & (pop_data[DATA_MSB:DATA_LSB] >> (pop_data[OFFSET_MSB:OFFSET_LSB] * 8))) << (8 * (ctrl_offset + aligned_bytes_processed)));
                push_data[SIZE_MSB:SIZE_LSB]     <= ctrl_size;
                push_data[OFFSET_MSB:OFFSET_LSB] <= ctrl_offset;
                
                unaligned_offset                 <= pop_data[OFFSET_MSB:OFFSET_LSB];
                unaligned_size                   <= pop_data[SIZE_MSB:SIZE_LSB];
                unaligned_data                   <= pop_data[DATA_MSB:DATA_LSB];
                unaligned_bytes_processed        <= ctrl_size - aligned_bytes_processed;
                
                if(pop_data[SIZE_MSB:SIZE_LSB] == (ctrl_size - aligned_bytes_processed)) begin
                  pop_ready <= 1;
                end
                else begin
                  pop_ready <= 0;
                end
                
              end
              else begin
                 //There is no enough information on the buffered unaligned bytes to aligned it - just prepare what is available for alignment
                
                push_valid                <= 0;
                push_data                 <= push_data | (((('h1 << (pop_data[SIZE_MSB:SIZE_LSB] * 8)) - 1) & (pop_data[DATA_MSB:DATA_LSB] >> (pop_data[OFFSET_MSB:OFFSET_LSB] * 8))) << (8 * (ctrl_offset + aligned_bytes_processed)));
                aligned_bytes_processed   <= aligned_bytes_processed + pop_data[SIZE_MSB:SIZE_LSB];
                
                unaligned_offset          <= pop_data[OFFSET_MSB:OFFSET_LSB];
                unaligned_size            <= pop_data[SIZE_MSB:SIZE_LSB];
                unaligned_data            <= pop_data[DATA_MSB:DATA_LSB];
                unaligned_bytes_processed <= pop_data[SIZE_MSB:SIZE_LSB];
                
                //Already accept any future incomming unaligned data
                pop_ready                 <= 1;
              end
            end
            else if((pop_valid == 1) && (pop_ready == 0)) begin
              //Accept any incomming unaligned data
              pop_ready <= 1;
            end
            else begin
              //Already accept any incomming unaligned data
              pop_ready <= 1;
            end
          end
          else begin
            //There is still some buffered unaligned bytes which can be processed
            
            if(unaligned_size - unaligned_bytes_processed >= (ctrl_size - aligned_bytes_processed)) begin
              //There is enough information in the buffered unaligned data to send an aligned packet
              
              push_valid                       <= 1;
              push_data[DATA_MSB:DATA_LSB]     <= push_data[DATA_MSB:DATA_LSB] | (((('h1 << ((ctrl_size - aligned_bytes_processed) * 8)) - 1) & (unaligned_data >> ((unaligned_offset + unaligned_bytes_processed) * 8))) << (8 * (ctrl_offset + aligned_bytes_processed)));
              push_data[SIZE_MSB:SIZE_LSB]     <= ctrl_size;
              push_data[OFFSET_MSB:OFFSET_LSB] <= ctrl_offset;
              
              unaligned_bytes_processed        <= unaligned_bytes_processed + ctrl_size - aligned_bytes_processed;

              if(unaligned_bytes_processed + ctrl_size - aligned_bytes_processed >= unaligned_size) begin
                //Already accept any incomming unaligned data
                pop_ready <= 1;
              end
              else begin
                pop_ready <= 0;
              end
            end
            else begin
              //There is no enough information on the buffered unaligned bytes to aligned it - just prepare what is available for alignment
              
              push_valid                <= 0;
              push_data                 <= push_data | (((('h1 << ((unaligned_size - unaligned_bytes_processed) * 8)) - 1) & (unaligned_data >> ((unaligned_offset + unaligned_bytes_processed) * 8))) << (8 * (ctrl_offset + aligned_bytes_processed)));
              aligned_bytes_processed   <= aligned_bytes_processed + (unaligned_size - unaligned_bytes_processed) ;
              
              unaligned_bytes_processed <= unaligned_size;

              //Already accept any incomming unaligned data
              pop_ready <= 1;
            end
          end
        end
      end
    end
    
  endmodule

`endif

`ifndef CFS_TX_CTRL_V
  `define CFS_TX_CTRL_V

  module cfs_tx_ctrl #(
    parameter ALGN_DATA_WIDTH = 32,

    localparam int unsigned ALGN_OFFSET_WIDTH = ALGN_DATA_WIDTH <= 8 ? 1 : $clog2(ALGN_DATA_WIDTH/8),
    localparam int unsigned ALGN_SIZE_WIDTH   = $clog2(ALGN_DATA_WIDTH/8)+1,
    localparam int unsigned FIFO_DATA_WIDTH   = ALGN_DATA_WIDTH + ALGN_OFFSET_WIDTH + ALGN_SIZE_WIDTH
  )(
    input                              pop_valid,
    input[FIFO_DATA_WIDTH-1:0]         pop_data,
    output wire                        pop_ready,

    output wire                        md_tx_valid,
    output wire[ALGN_DATA_WIDTH-1:0]   md_tx_data,
    output wire[ALGN_OFFSET_WIDTH-1:0] md_tx_offset,
    output wire[ALGN_SIZE_WIDTH-1:0]   md_tx_size,
    input                              md_tx_ready
    );
    
    localparam int unsigned DATA_MSB = ALGN_DATA_WIDTH-1;
    localparam int unsigned DATA_LSB = 0;
    
    localparam int unsigned OFFSET_MSB = ALGN_DATA_WIDTH+ALGN_OFFSET_WIDTH-1;
    localparam int unsigned OFFSET_LSB = ALGN_DATA_WIDTH;
    
    localparam int unsigned SIZE_MSB = ALGN_DATA_WIDTH+ALGN_OFFSET_WIDTH+ALGN_SIZE_WIDTH-1;
    localparam int unsigned SIZE_LSB = ALGN_DATA_WIDTH+ALGN_OFFSET_WIDTH;
    
    assign pop_ready    = pop_valid & md_tx_ready;
    assign md_tx_valid  = pop_valid;
    assign md_tx_data   = pop_data[DATA_MSB:DATA_LSB];
    assign md_tx_offset = pop_data[OFFSET_MSB:OFFSET_LSB];
    assign md_tx_size   = pop_data[SIZE_MSB:SIZE_LSB];
    
  endmodule

`endif

`ifndef CFS_EDGE_DETECT_V
  `define CFS_EDGE_DETECT_V
  
  module cfs_edge_detect #(parameter bit EDGE = 1, parameter bit RESET_VAL = !EDGE)(
    input clk,
    input reset_n,
    input data,
    
    output reg detected
  );
    
    reg dly1_data;
    
    always@(posedge clk or negedge reset_n) begin
      if(reset_n == 0) begin
        dly1_data <= RESET_VAL;
      end
      else begin
        dly1_data <= data;
      end
    end
    
    assign detected = ((data == EDGE) & (dly1_data == !EDGE));
    
  endmodule

`endif

`ifndef CFS_REGS_V
  `define CFS_REGS_V

  module cfs_regs#(
    parameter APB_ADDR_WIDTH        = 16,
    parameter ALGN_DATA_WIDTH       = 32,
    
    parameter STATUS_CNT_DROP_WIDTH = 8,
    parameter STATUS_RX_LVL_WIDTH   = 4,
    parameter STATUS_TX_LVL_WIDTH   = 4,
    
    localparam int unsigned APB_DATA_WIDTH  = 32,
    localparam int unsigned ALGN_OFFSET_WIDTH = ALGN_DATA_WIDTH <= 8 ? 1 : $clog2(ALGN_DATA_WIDTH/8),
    localparam int unsigned ALGN_SIZE_WIDTH   = $clog2(ALGN_DATA_WIDTH/8)+1) (
    
    input wire                            pclk,
    input wire                            presetn,

    input wire[APB_ADDR_WIDTH-1:0]        paddr,
    input wire                            pwrite,
    input wire                            psel,
    input wire                            penable,
    input wire[APB_DATA_WIDTH-1:0]        pwdata,
    output reg                            pready,
    output reg[APB_DATA_WIDTH-1:0]        prdata,
    output reg                            pslverr,
      
    output reg[ALGN_OFFSET_WIDTH-1:0]     ctrl_offset,
    output reg[ALGN_SIZE_WIDTH-1:0]       ctrl_size,
    output reg                            ctrl_clr,
    
    input wire[STATUS_CNT_DROP_WIDTH-1:0] status_cnt_drop,
    input wire[STATUS_RX_LVL_WIDTH-1:0]   status_rx_lvl,
    input wire[STATUS_TX_LVL_WIDTH-1:0]   status_tx_lvl,
    
    input wire                            rx_fifo_empty,
    input wire                            rx_fifo_full,
    input wire                            tx_fifo_empty,
    input wire                            tx_fifo_full,
    input wire                            max_drop,
    
    output wire                           irq
  );
    
    localparam ADDR_CTRL    = 'h0000;
    localparam ADDR_STATUS  = 'h000c;
    localparam ADDR_IRQEN   = 'h00f0;
    localparam ADDR_IRQ     = 'h00f4;
    
    localparam LSB_CTRL_SIZE   = 0;
    localparam LSB_CTRL_OFFSET = 8;
    localparam LSB_CTRL_CLR    = 16;
    
    localparam LSB_STATUS_CNT_DROP = 0;
    localparam LSB_STATUS_RX_LVL   = 8;
    localparam LSB_STATUS_TX_LVL   = 16;
    
    localparam LSB_IRQEN_RX_FIFO_EMPTY = 0;
    localparam LSB_IRQEN_RX_FIFO_FULL  = 1;
    localparam LSB_IRQEN_TX_FIFO_EMPTY = 2;
    localparam LSB_IRQEN_TX_FIFO_FULL  = 3;
    localparam LSB_IRQEN_MAX_DROP      = 4;
    
    localparam LSB_IRQ_RX_FIFO_EMPTY = LSB_IRQEN_RX_FIFO_EMPTY;
    localparam LSB_IRQ_RX_FIFO_FULL  = LSB_IRQEN_RX_FIFO_FULL;
    localparam LSB_IRQ_TX_FIFO_EMPTY = LSB_IRQEN_TX_FIFO_EMPTY;
    localparam LSB_IRQ_TX_FIFO_FULL  = LSB_IRQEN_TX_FIFO_FULL;
    localparam LSB_IRQ_MAX_DROP      = LSB_IRQEN_MAX_DROP;
    
    wire[APB_ADDR_WIDTH-1:0] addr_aligned;
  
    assign addr_aligned = {paddr[APB_ADDR_WIDTH-1:2], 2'b00};
    
    reg wr_ctrl_is_illegal;
    
    wire[ALGN_SIZE_WIDTH-1:0] ctrl_size_wr_val;
    
    assign ctrl_size_wr_val = pwdata[LSB_CTRL_SIZE + ALGN_SIZE_WIDTH - 1 : LSB_CTRL_SIZE];
                      
    wire[ALGN_OFFSET_WIDTH-1:0] ctrl_offset_wr_val;
    
    assign ctrl_offset_wr_val = pwdata[LSB_CTRL_OFFSET + ALGN_OFFSET_WIDTH - 1 : LSB_CTRL_OFFSET];
    
    reg[APB_DATA_WIDTH-1:0] ctrl_rd_val;
    
    reg irqen_rx_fifo_empty;
    reg irqen_rx_fifo_full;
    reg irqen_tx_fifo_empty;
    reg irqen_tx_fifo_full;
    reg irqen_max_drop;
    
    reg irq_rx_fifo_empty;
    reg irq_rx_fifo_full;
    reg irq_tx_fifo_empty;
    reg irq_tx_fifo_full;
    reg irq_max_drop;
    
    always_comb begin
      ctrl_rd_val = 0;
      
      ctrl_rd_val[LSB_CTRL_SIZE   + ALGN_SIZE_WIDTH   - 1 : LSB_CTRL_SIZE]   = ctrl_size;
      ctrl_rd_val[LSB_CTRL_OFFSET + ALGN_OFFSET_WIDTH - 1 : LSB_CTRL_OFFSET] = ctrl_offset;
    end
    
    reg[APB_DATA_WIDTH-1:0] status_rd_val;
    
    always_comb begin
      status_rd_val = 0;
      
      status_rd_val[LSB_STATUS_CNT_DROP+ STATUS_CNT_DROP_WIDTH-1:LSB_STATUS_CNT_DROP] = status_cnt_drop;
      status_rd_val[LSB_STATUS_RX_LVL  + STATUS_RX_LVL_WIDTH-1  :LSB_STATUS_RX_LVL]   = status_rx_lvl;
      status_rd_val[LSB_STATUS_TX_LVL  + STATUS_TX_LVL_WIDTH-1  :LSB_STATUS_TX_LVL]   = status_tx_lvl;
    end
    
    reg[APB_DATA_WIDTH-1:0] irqen_rd_val;
    
    always_comb begin
      irqen_rd_val = 0;
      
      irqen_rd_val[LSB_IRQEN_RX_FIFO_EMPTY] = irqen_rx_fifo_empty;
      irqen_rd_val[LSB_IRQEN_RX_FIFO_FULL]  = irqen_rx_fifo_full;
      irqen_rd_val[LSB_IRQEN_TX_FIFO_EMPTY] = irqen_tx_fifo_empty;
      irqen_rd_val[LSB_IRQEN_TX_FIFO_FULL]  = irqen_tx_fifo_full;
      irqen_rd_val[LSB_IRQEN_MAX_DROP]      = irqen_max_drop;
    end
    
    reg[APB_DATA_WIDTH-1:0] irq_rd_val;
    
    always_comb begin
      irq_rd_val = 0;
      
      irq_rd_val[LSB_IRQEN_RX_FIFO_EMPTY] = irq_rx_fifo_empty;
      irq_rd_val[LSB_IRQEN_RX_FIFO_FULL]  = irq_rx_fifo_full;
      irq_rd_val[LSB_IRQEN_TX_FIFO_EMPTY] = irq_tx_fifo_empty;
      irq_rd_val[LSB_IRQEN_TX_FIFO_FULL]  = irq_tx_fifo_full;
      irq_rd_val[LSB_IRQEN_MAX_DROP]      = irq_max_drop;
    end
    
    wire edge_rx_fifo_empty;
    wire edge_rx_fifo_full;
    wire edge_tx_fifo_empty;
    wire edge_tx_fifo_full;
    wire edge_max_drop;
    
    cfs_edge_detect #(.EDGE(1), .RESET_VAL(1)) edge_detect_rx_fifo_empty(.clk(pclk), .reset_n(presetn), .data(rx_fifo_empty), .detected(edge_rx_fifo_empty));
    cfs_edge_detect #(.EDGE(1), .RESET_VAL(0)) edge_detect_rx_fifo_full( .clk(pclk), .reset_n(presetn), .data(rx_fifo_full),  .detected(edge_rx_fifo_full));
    cfs_edge_detect #(.EDGE(1), .RESET_VAL(1)) edge_detect_tx_fifo_empty(.clk(pclk), .reset_n(presetn), .data(tx_fifo_empty), .detected(edge_tx_fifo_empty));
    cfs_edge_detect #(.EDGE(1), .RESET_VAL(0)) edge_detect_tx_fifo_full( .clk(pclk), .reset_n(presetn), .data(tx_fifo_full),  .detected(edge_tx_fifo_full));
    cfs_edge_detect #(.EDGE(1), .RESET_VAL(0)) edge_detect_max_drop(     .clk(pclk), .reset_n(presetn), .data(max_drop),      .detected(edge_max_drop));
    
    assign irq = 
      (edge_rx_fifo_empty & irqen_rx_fifo_empty) | 
      (edge_rx_fifo_full  & irqen_rx_fifo_full)  | 
      (edge_tx_fifo_empty & irqen_tx_fifo_empty) | 
      (edge_tx_fifo_full  & irqen_tx_fifo_full);
    
    always@(posedge pclk or negedge presetn) begin
      if(presetn == 0) begin
        ctrl_offset <= 0;
        ctrl_size   <= 1;
        
        irqen_rx_fifo_empty <= 1;
        irqen_rx_fifo_full  <= 1;
        irqen_tx_fifo_empty <= 1;
        irqen_tx_fifo_full  <= 1;
        irqen_max_drop      <= 1;
        
        irq_rx_fifo_empty <= 0;
        irq_rx_fifo_full  <= 0;
        irq_tx_fifo_empty <= 0;
        irq_tx_fifo_full  <= 0;
        irq_max_drop      <= 0;
        
        wr_ctrl_is_illegal <= 0;
        
        ctrl_clr           <= 0;
      end
      else begin
        ctrl_clr <= 0;
        
        if(psel == 1 && penable == 1) begin
          if(pready == 0) begin
            case(addr_aligned) 
              ADDR_CTRL : begin
                if(pwrite) begin
                  if(wr_ctrl_is_illegal == 0) begin
                    if(ctrl_size_wr_val == 0) begin
                      wr_ctrl_is_illegal <= 1;
                      pready             <= 0;
                      pslverr            <= 0;
                    end
                    else if(((ALGN_DATA_WIDTH / 8) + ctrl_offset_wr_val) % ctrl_size_wr_val != 0) begin
                      wr_ctrl_is_illegal <= 1;
                      pready             <= 0;
                      pslverr            <= 0;
                    end
                    else begin
                      wr_ctrl_is_illegal <= 0;
                      pready             <= 1;
                      pslverr            <= 0;
                      
                      ctrl_size          <= ctrl_size_wr_val;
                      ctrl_offset        <= ctrl_offset_wr_val;
                      ctrl_clr           <= pwdata[LSB_CTRL_CLR];
                    end
                  end
                  else begin
                    wr_ctrl_is_illegal <= 0;
                    pready             <= 1;
                    pslverr            <= 1;
                  end
                end
                else begin
                  prdata <= ctrl_rd_val;
                  pready <= 1;
                end
              end
              ADDR_STATUS : begin
                if(pwrite) begin
                  pready  <= 1;
                  pslverr <= 1;
                  prdata  <= 0;
                end
                else begin
                  pready  <= 1;
                  pslverr <= 0;
                  prdata  <= status_rd_val;
                end
              end
              ADDR_IRQEN : begin
                if(pwrite) begin
                  pready  <= 1;
                  pslverr <= 0;
                  
                  irqen_rx_fifo_empty <= pwdata[LSB_IRQEN_RX_FIFO_EMPTY];
                  irqen_rx_fifo_full  <= pwdata[LSB_IRQEN_RX_FIFO_FULL];
                  irqen_tx_fifo_empty <= pwdata[LSB_IRQEN_TX_FIFO_EMPTY];
                  irqen_tx_fifo_full  <= pwdata[LSB_IRQEN_TX_FIFO_FULL];
                  irqen_max_drop      <= pwdata[LSB_IRQEN_MAX_DROP];
                end
                else begin
                  pready  <= 1;
                  pslverr <= 0;
                  prdata  <= irqen_rd_val;
                end
              end
              ADDR_IRQ : begin
                if(pwrite) begin
                  pready  <= 1;
                  pslverr <= 0;
                  
                  irq_rx_fifo_empty <= irq_rx_fifo_empty & !pwdata[LSB_IRQEN_RX_FIFO_EMPTY];
                  irq_rx_fifo_full  <= irq_rx_fifo_full  & !pwdata[LSB_IRQEN_RX_FIFO_FULL];
                  irq_tx_fifo_empty <= irq_tx_fifo_empty & !pwdata[LSB_IRQEN_TX_FIFO_EMPTY];
                  irq_tx_fifo_full  <= irq_tx_fifo_full  & !pwdata[LSB_IRQEN_TX_FIFO_FULL];
                  irq_max_drop      <= irq_max_drop      & !pwdata[LSB_IRQEN_MAX_DROP];
                end
                else begin
                  pready  <= 1;
                  pslverr <= 0;
                  prdata  <= irq_rd_val;
                end
              end
              default : begin
                pready  <= 1;
                pslverr <= 1;
                prdata  <= 0;
              end
            endcase
          end
          else begin
            pready  <= 0;
            pslverr <= 0;
            prdata  <= 0;
          end
        end
        else begin
          pready  <= 0;
          pslverr <= 0;
          prdata  <= 0;
        end
        
        if(edge_rx_fifo_empty) begin
          irq_rx_fifo_empty <= 1;
        end
        
        if(edge_rx_fifo_full) begin
          irq_rx_fifo_full <= 1;
        end
        
        if(edge_tx_fifo_empty) begin
          irq_tx_fifo_empty <= 1;
        end
        
        if(edge_tx_fifo_full) begin
          irq_tx_fifo_full <= 1;
        end
        
        if(edge_max_drop) begin
          irq_max_drop <= 1;
        end
      end
    end

  endmodule

`endif

`ifndef CFS_ALIGNER_CORE_V
  `define CFS_ALIGNER_CORE_V
  module cfs_aligner_core#(
    parameter APB_ADDR_WIDTH  = 16,
    parameter ALGN_DATA_WIDTH = 32,
    parameter FIFO_DEPTH      = 8,
    
     //Clock Domain Crossing - RX domain to register access domain
     //Set this parameter to 0 only if md_rx_clk and pclk are tied to the same clock signal.
     parameter CDC_RX_TO_REG  = 1,

     //Clock Domain Crossing - register access domain to TX domain
     //Set this parameter to 0 only if pclk and md_tx_clk are tied to the same clock signal.
     parameter CDC_REG_TO_TX  = 1,

    localparam int unsigned STATUS_CNT_DROP_WIDTH = 8,

    localparam int unsigned APB_DATA_WIDTH  = 32,

    localparam int unsigned ALGN_OFFSET_WIDTH = ALGN_DATA_WIDTH <= 8 ? 1 : $clog2(ALGN_DATA_WIDTH/8),
    localparam int unsigned ALGN_SIZE_WIDTH   = $clog2(ALGN_DATA_WIDTH/8)+1
  ) (
    input wire pclk,
    input wire preset_n,

    input wire[APB_ADDR_WIDTH-1:0]    paddr,
    input wire                        pwrite,
    input wire                        psel,
    input wire                        penable,
    input wire[APB_DATA_WIDTH-1:0]    pwdata,
    output wire                       pready,
    output reg[APB_DATA_WIDTH-1:0]    prdata,
    output reg                        pslverr,

    input                             md_rx_clk,
    input                             md_rx_valid,
    input[ALGN_DATA_WIDTH-1:0]        md_rx_data,
    input[ALGN_OFFSET_WIDTH-1:0]      md_rx_offset,
    input[ALGN_SIZE_WIDTH-1:0]        md_rx_size,
    output reg                        md_rx_ready,
    output reg                        md_rx_err,

    input                             md_tx_clk,
    output reg                        md_tx_valid,
    output reg[ALGN_DATA_WIDTH-1:0]   md_tx_data,
    output reg[ALGN_OFFSET_WIDTH-1:0] md_tx_offset,
    output reg[ALGN_SIZE_WIDTH-1:0]   md_tx_size,
    input                             md_tx_ready,
    input                             md_tx_err,

    output wire                       irq
  );

    localparam int unsigned FIFO_WIDTH        = ALGN_DATA_WIDTH + ALGN_OFFSET_WIDTH + ALGN_SIZE_WIDTH;
    localparam int unsigned FIFO_LVL_WIDTH    = $clog2(FIFO_DEPTH) + 1;

    initial begin
      assert(APB_ADDR_WIDTH >= 12) else begin
        $error($sformatf("Legal values for APB_ADDR_WIDTH parameter must greater of equal than 12 but found 'd%0d", APB_ADDR_WIDTH));
      end

      assert($countones(ALGN_DATA_WIDTH) == 1) else begin
        $error($sformatf("Legal values for ALGN_DATA_WIDTH parameter must be a power of two but found 'd%0d", ALGN_DATA_WIDTH));
      end

      assert(ALGN_DATA_WIDTH >= 8) else begin
        $error($sformatf("Legal values for ALGN_DATA_WIDTH parameter must be greater or equal than 8 but found 'd%0d", ALGN_DATA_WIDTH));
      end
    end

    wire[STATUS_CNT_DROP_WIDTH-1:0] rx_ctrl_2_regs_status_cnt_drop;
    wire                            regs_2_rx_ctrl_ctrl_clr;
    wire                            rx_ctrl_2_rx_fifo_push_valid;
    wire[FIFO_WIDTH-1:0]            rx_ctrl_2_rx_fifo_push_data;
    wire                            rx_fifo_2_rx_ctrl_push_ready;
    wire                            rx_fifo_2_rx_ctrl_push_full;
    wire                            rx_fifo_2_regs_fifo_full;
    wire                            rx_fifo_2_regs_fifo_empty;
    wire[FIFO_LVL_WIDTH-1:0]        rx_fifo_2_regs_fifo_lvl;
    wire[FIFO_LVL_WIDTH-1:0]        tx_fifo_2_regs_fifo_lvl;
    wire                            tx_fifo_2_regs_fifo_empty;
    wire                            tx_fifo_2_regs_fifo_full;
    wire                            tx_fifo_2_tx_ctrl_pop_valid;
    wire[FIFO_WIDTH-1:0]            tx_fifo_2_tx_ctrl_pop_data;
    wire                            tx_fifo_2_tx_ctrl_pop_ready;
    wire                            rx_fifo_2_ctrl_pop_valid;
    wire[FIFO_WIDTH-1:0]            rx_fifo_2_ctrl_pop_data;
    wire                            rx_fifo_2_ctrl_pop_ready;
    wire                            ctrl_2_tx_fifo_push_valid;
    wire[FIFO_WIDTH-1:0]            ctrl_2_tx_fifo_push_data;
    wire                            ctrl_2_tx_fifo_push_ready;
    wire[ALGN_OFFSET_WIDTH-1:0]     regs_2_ctrl_ctrl_offset;
    wire[ALGN_SIZE_WIDTH-1:0]       regs_2_ctrl_ctrl_size;

    cfs_rx_ctrl #(
      .ALGN_DATA_WIDTH      (ALGN_DATA_WIDTH),
      .STATUS_CNT_DROP_WIDTH(STATUS_CNT_DROP_WIDTH)
    ) rx_ctrl (
      .preset_n       (preset_n),
      .pclk           (pclk),

      .status_cnt_drop(rx_ctrl_2_regs_status_cnt_drop),
      .clr_cnt_dop    (regs_2_rx_ctrl_ctrl_clr),

      .md_rx_clk      (md_rx_clk),
      .md_rx_valid    (md_rx_valid),
      .md_rx_data     (md_rx_data),
      .md_rx_offset   (md_rx_offset),
      .md_rx_size     (md_rx_size),
      .md_rx_ready    (md_rx_ready),
      .md_rx_err      (md_rx_err),

      .push_valid     (rx_ctrl_2_rx_fifo_push_valid),
      .push_data      (rx_ctrl_2_rx_fifo_push_data),
      .push_ready     (rx_fifo_2_rx_ctrl_push_ready),

      .rx_fifo_full   (rx_fifo_2_rx_ctrl_push_full)
    );

    cfs_synch_fifo #(
      .DATA_WIDTH(FIFO_WIDTH),
      .FIFO_DEPTH(FIFO_DEPTH),
      .CDC(       CDC_RX_TO_REG)) rx_fifo (
      .reset_n      (preset_n),

      .push_clk     (md_rx_clk),
      .push_valid   (rx_ctrl_2_rx_fifo_push_valid),
      .push_data    (rx_ctrl_2_rx_fifo_push_data),
      .push_ready   (rx_fifo_2_rx_ctrl_push_ready),

      .push_full    (rx_fifo_2_rx_ctrl_push_full),

      .push_empty   (),

      .push_fifo_lvl(),

      .pop_clk      (pclk),
      .pop_valid    (rx_fifo_2_ctrl_pop_valid),
      .pop_data     (rx_fifo_2_ctrl_pop_data),
      .pop_ready    (rx_fifo_2_ctrl_pop_ready),

      .pop_full     (rx_fifo_2_regs_fifo_full),

      .pop_empty    (rx_fifo_2_regs_fifo_empty),

      .pop_fifo_lvl (rx_fifo_2_regs_fifo_lvl)
    );

    cfs_synch_fifo #(
      .DATA_WIDTH(FIFO_WIDTH),
      .FIFO_DEPTH(FIFO_DEPTH),
      .CDC(       CDC_REG_TO_TX)) tx_fifo (
      .reset_n   (preset_n),

      .push_clk  (pclk),
      .push_valid(ctrl_2_tx_fifo_push_valid),
      .push_data (ctrl_2_tx_fifo_push_data),
      .push_ready(ctrl_2_tx_fifo_push_ready),

      .push_full (tx_fifo_2_regs_fifo_full),

      .push_empty(tx_fifo_2_regs_fifo_empty),

      .push_fifo_lvl(tx_fifo_2_regs_fifo_lvl),

      .pop_clk   (md_tx_clk),
      .pop_valid (tx_fifo_2_tx_ctrl_pop_valid),
      .pop_data  (tx_fifo_2_tx_ctrl_pop_data),
      .pop_ready (tx_fifo_2_tx_ctrl_pop_ready),

      .pop_full  (),

      .pop_empty (),

      .pop_fifo_lvl ()
    );

    cfs_tx_ctrl #(
      .ALGN_DATA_WIDTH(ALGN_DATA_WIDTH)
    ) tx_ctrl (
      .pop_valid   (tx_fifo_2_tx_ctrl_pop_valid),
      .pop_data    (tx_fifo_2_tx_ctrl_pop_data),
      .pop_ready   (tx_fifo_2_tx_ctrl_pop_ready),

      .md_tx_valid (md_tx_valid),
      .md_tx_data  (md_tx_data),
      .md_tx_offset(md_tx_offset),
      .md_tx_size  (md_tx_size),
      .md_tx_ready (md_tx_ready)
    );

    cfs_ctrl #(
      .ALGN_DATA_WIDTH(ALGN_DATA_WIDTH)
    ) ctrl(
      .reset_n    (preset_n),
      .clk        (pclk),

      .pop_valid  (rx_fifo_2_ctrl_pop_valid),
      .pop_data   (rx_fifo_2_ctrl_pop_data),
      .pop_ready  (rx_fifo_2_ctrl_pop_ready),

      .push_valid (ctrl_2_tx_fifo_push_valid),
      .push_data  (ctrl_2_tx_fifo_push_data),
      .push_ready (ctrl_2_tx_fifo_push_ready),

      .ctrl_offset(regs_2_ctrl_ctrl_offset),
      .ctrl_size  (regs_2_ctrl_ctrl_size)
      );

    cfs_regs#(
      .APB_ADDR_WIDTH       (APB_ADDR_WIDTH),
      .STATUS_CNT_DROP_WIDTH(STATUS_CNT_DROP_WIDTH),
      .ALGN_DATA_WIDTH      (ALGN_DATA_WIDTH)) regs (
      .pclk           (pclk),
      .presetn        (preset_n),
      .paddr          (paddr),
      .pwrite         (pwrite),
      .psel           (psel),
      .penable        (penable),
      .pwdata         (pwdata),
      .pready         (pready),
      .prdata         (prdata),
      .pslverr        (pslverr),

      .ctrl_offset    (regs_2_ctrl_ctrl_offset),
      .ctrl_size      (regs_2_ctrl_ctrl_size),
      .ctrl_clr       (regs_2_rx_ctrl_ctrl_clr),

      .status_cnt_drop(rx_ctrl_2_regs_status_cnt_drop),
      .status_rx_lvl  (rx_fifo_2_regs_fifo_lvl),
      .status_tx_lvl  (tx_fifo_2_regs_fifo_lvl),

      .rx_fifo_empty  (rx_fifo_2_regs_fifo_empty),
      .rx_fifo_full   (rx_fifo_2_regs_fifo_full),
      .tx_fifo_empty  (tx_fifo_2_regs_fifo_empty),
      .tx_fifo_full   (tx_fifo_2_regs_fifo_full),
      .max_drop       (rx_ctrl_2_regs_status_cnt_drop == (('h1 << STATUS_CNT_DROP_WIDTH) - 1)),
      
      .irq            (irq)
    );
  endmodule

`endif

`ifndef CFS_ALIGNER_V
  `define CFS_ALIGNER_V
  module cfs_aligner#(
    parameter ALGN_DATA_WIDTH = 32,
    parameter FIFO_DEPTH      = 8,
    
    localparam int unsigned APB_ADDR_WIDTH    = 16,
    localparam int unsigned APB_DATA_WIDTH    = 32,
    localparam int unsigned ALGN_OFFSET_WIDTH = ALGN_DATA_WIDTH <= 8 ? 1 : $clog2(ALGN_DATA_WIDTH/8),
    localparam int unsigned ALGN_SIZE_WIDTH   = $clog2(ALGN_DATA_WIDTH/8)+1
  ) (
    input wire clk,
    input wire reset_n,
    
    input wire[APB_ADDR_WIDTH-1:0]    paddr,
    input wire                        pwrite,
    input wire                        psel,
    input wire                        penable,
    input wire[APB_DATA_WIDTH-1:0]    pwdata,
    output wire                       pready,
    output reg[APB_DATA_WIDTH-1:0]    prdata,
    output reg                        pslverr,
    
    input                             md_rx_valid,
    input[ALGN_DATA_WIDTH-1:0]        md_rx_data,
    input[ALGN_OFFSET_WIDTH-1:0]      md_rx_offset,
    input[ALGN_SIZE_WIDTH-1:0]        md_rx_size,
    output reg                        md_rx_ready,
    output reg                        md_rx_err,
    
    output reg                        md_tx_valid,
    output reg[ALGN_DATA_WIDTH-1:0]   md_tx_data,
    output reg[ALGN_OFFSET_WIDTH-1:0] md_tx_offset,
    output reg[ALGN_SIZE_WIDTH-1:0]   md_tx_size,
    input                             md_tx_ready,
    input                             md_tx_err,
    
    output reg                        irq
  );
    
    localparam int unsigned STATUS_CNT_DROP_WIDTH = 8;
    
    cfs_aligner_core#(
      .APB_ADDR_WIDTH( APB_ADDR_WIDTH),
      .ALGN_DATA_WIDTH(ALGN_DATA_WIDTH),
      .FIFO_DEPTH(     FIFO_DEPTH),
      .CDC_RX_TO_REG(  0),
      .CDC_REG_TO_TX(  0)) core (
      .pclk        (clk),
      .preset_n    (reset_n),
    
      .paddr       (paddr),
      .pwrite      (pwrite),
      .psel        (psel),
      .penable     (penable),
      .pwdata      (pwdata),
      .pready      (pready),
      .prdata      (prdata),
      .pslverr     (pslverr),
  
      .md_rx_clk   (clk),
      .md_rx_valid (md_rx_valid),
      .md_rx_data  (md_rx_data),
      .md_rx_offset(md_rx_offset),
      .md_rx_size  (md_rx_size),
      .md_rx_ready (md_rx_ready),
      .md_rx_err   (md_rx_err),
  
      .md_tx_clk   (clk),
      .md_tx_valid (md_tx_valid),
      .md_tx_data  (md_tx_data),
      .md_tx_offset(md_tx_offset),
      .md_tx_size  (md_tx_size),
      .md_tx_ready (md_tx_ready),
      .md_tx_err   (md_tx_err),
  
      .irq         (irq)
    );
  endmodule
`endif