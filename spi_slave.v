module spi_slave
    #(
      parameter DATA_WIDTH = 8
     )

    (
      input [1:0] MODE,
      input [DATA_WIDTH-1:0] TxData,        // Transmit Data

      output Done,                          // Transmit Completed
      output reg [DATA_WIDTH-1:0] RxData,   // Receive Data

// SPI Interface Signals
      input  SClk,                          // SPI clock
      input  MOSI,                          // Master Out Slave In
      input  SS,                            // Slave Select
      output MISO                           // Master In Slave Out
    );

    wire ClkPol;
    wire ClkPha;
    reg  Dout;

// Bit counter
    reg [DATA_WIDTH-1:0] bitcnt;

// Generate polarity & phase signals for the various SPI modes
// Clock Polarity. 0=Idle at '0' with pulse of '1'.
//                 1=Idle at '1' with pulse of '0'
    assign ClkPol = (MODE[1:0] == 2'b10) || (MODE[1:0] == 2'b11);
// Clock Phase. 0=Change data on trailing edge, capture on leading edge.
//              1=Change data on leading edge, capture on trailing edge.
    assign ClkPha = (MODE[1:0] == 2'b01) || (MODE[1:0] == 2'b11);

// Slave shift register
    reg [DATA_WIDTH-1:0] txreg;

    assign MISO = (SS) ? 1'bz: Dout;

// Load the transmit data into Slave shift register
    always @ (negedge SS)
      begin
        txreg <= TxData;
        bitcnt <= 0;
        if ( ClkPha == 1'b0 )
          begin
            Dout <= TxData[DATA_WIDTH-1];
            txreg <= {TxData[DATA_WIDTH-2:0], 1'b0};
          end
      end

    always @ (posedge SClk)
      case ( {ClkPol, ClkPha} )
        2'b00: RxData <= {RxData[DATA_WIDTH-2:0], MOSI};
        2'b01, 
        2'b10: begin
                 txreg <= {txreg[DATA_WIDTH-2:0], 1'b0};
                 Dout <= txreg[DATA_WIDTH-1];
               end
        2'b11: RxData <= {RxData[DATA_WIDTH-2:0], MOSI};
        default: ;
      endcase

    always @ (negedge SClk)
      case ( {ClkPol, ClkPha} )
        2'b00: begin
                 txreg <= {txreg[DATA_WIDTH-2:0], 1'b0};
                 Dout <= txreg[DATA_WIDTH-1];
               end
        2'b01, 
        2'b10: RxData <= {RxData[DATA_WIDTH-2:0], MOSI};
        2'b11: begin
                 txreg <= {txreg[DATA_WIDTH-2:0], 1'b0};
                 Dout <= txreg[DATA_WIDTH-1];
               end
        default: ;
      endcase

// data-bit count is clocked using SPI clock (SClk)
// Set XferComplete when the MSB of the bit counter is '1'.
    assign Done = bitcnt[DATA_WIDTH-1];

    always @ (negedge SClk)
      if ( SS == 1'b0 )
        bitcnt <= {bitcnt[DATA_WIDTH-2:0], 1'b1};
      else
        bitcnt <= bitcnt;

endmodule