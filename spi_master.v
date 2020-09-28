module spi_master 
    #(
      parameter DATA_WIDTH = 8,
      parameter SPI_MODE = 0
     )

    (
      input Clk,                      // 50-MHz clock
      input Reset,                    // Global Reset
      input Start,                    // Start transmitting (also used to register TxData)
      input [1:0] ClkDiv,             // Clock divider: 0 => /4
                                      //                1 => /8
                                      //                2 => /16
                                      //                3 => /32
      input [DATA_WIDTH-1:0] TxData,  // Transmit Data

      output reg Done,                // Transmit Completed
      output reg [DATA_WIDTH-1:0] RxData, // Receive Data

// SPI Interface Signals
      input  MISO,                    // Master In Slave Out
      output reg SClk,                // SPI Clock
      output reg MOSI,                // Master Out Slave In
      output reg SS                   // Slave Select
    );

    wire ClkPol;
    wire ClkPha;
    wire XferComplete;

// Frequency dividing logic to generate midCyc signal.
    wire ClkEn;
    wire [4:0] next_count;
    reg  [4:0] count;
    reg  [3:0] halfcyc;
    reg        midCyc;

// FSM States for generating SPI Clock
    localparam  IDLE  = 2'b11,
                BEGIN = 2'b10,
                LEAD  = 2'b01,
                TRAIL = 2'b00;

// FSM to generate SPI Clock
    reg [1:0] current_state, next_state;
// Master shift register
    reg [DATA_WIDTH-1:0] txreg;

// Bit counter
    reg [DATA_WIDTH-1:0] bitcnt;

// Generate polarity & phase signals for the various SPI modes
// Clock Polarity. 0=Idle at '0' with pulse of '1'.
//                 1=Idle at '1' with pulse of '0'
    assign ClkPol = (SPI_MODE == 2) || (SPI_MODE == 3);
// Clock Phase. 0=Change data on trailing edge, capture on leading edge.
//              1=Change data on leading edge, capture on trailing edge.
    assign ClkPha = (SPI_MODE == 1) || (SPI_MODE == 3);

// midCyc logic. Asserts when the frequency is half cycle base on ClkDiv[1:0]
    assign next_count[4:0] = count[4:0] + 1;
    assign ClkEn = (next_count == {halfcyc,1'b0});

    always @ (posedge Clk or posedge Reset)
      if ( Reset || (current_state == 2'b11) ) begin
        count <= 5'b0;
        midCyc <= 1'b0;
      end else if ( ClkEn ) begin
        midCyc <= 1'b1;
        count <= 5'b0;
      end else begin
        midCyc <= 1'b0;
        count <= next_count;
      end

// Selects clock divider for SPI Clock
    always @ (ClkDiv)
      case ( ClkDiv[1:0] )
        2'b00: halfcyc = 4'b0001;     // Clk/4
        2'b01: halfcyc = 4'b0010;     // Clk/8
        2'b10: halfcyc = 4'b0100;     // Clk/16
        2'b11: halfcyc = 4'b1000;     // Clk/32
        default: halfcyc = 4'b0001;   // Clk/4
      endcase

// Next-State logic. Also use to generate SS (Slave Select) as well as SPI Clock
    always @ (current_state or Start or midCyc or XferComplete or MISO)
    begin
      case ( current_state )
        IDLE: begin
                SS <= 1'b1;
                SClk <= ClkPol;
                MOSI <= 1'b0;
                Done <= 1'b1;
                if ( !Start ) begin
                  next_state <= IDLE;
                end else
                  next_state <= BEGIN;
              end
        BEGIN: begin
                 next_state <= LEAD;
                 SS <= 1'b0;
                 Done <= 1'b0;
// MOSI is driven for the case where a transmission is started and CPHA = 0
                 if ( !ClkPha )
                   MOSI <= txreg[DATA_WIDTH-1];
                 else
                   MOSI <= 1'b0;
               end
        LEAD : begin
                SClk <= ClkPol ^ current_state[0];
                 if ( midCyc )
                   next_state <= TRAIL;
                 else
                   next_state <= LEAD;
               end
        TRAIL: begin
                 SClk <= ClkPol ^ current_state[0];
                 if ( XferComplete ) begin
                   next_state <= IDLE;
                   Done <= 1'b1;
                 end else if ( midCyc )
                   next_state <= LEAD;
                 else
                   next_state <= TRAIL;
               end
        default:
                 next_state <= IDLE;
      endcase
    end

// Update State
    always @ (posedge Clk or posedge Reset)
      if ( Reset )
        current_state <= IDLE;
      else
        current_state <= next_state;

// Load TxData into Master Shift Register
    always @ (posedge Clk or posedge Reset)
      if ( Reset ) begin
        txreg <= 0;
        RxData <= 0;
      end else if ( Start )
        txreg <= TxData;
      else
        txreg <= txreg;

// data bit count is clocked using SPI clock.
// Set XferComplete when the MSB of the bit counter is '1'.
    assign XferComplete = bitcnt[DATA_WIDTH-1];

    always @ (negedge SClk or posedge Reset)
      if ( Reset )
        bitcnt <= 0;
      else
        bitcnt <= {bitcnt[DATA_WIDTH-2:0], 1'b1};

// Handles the rising edge of SClk for all 4 SPI modes
    always @ (posedge SClk)
      case ( {ClkPol, ClkPha} )
        2'b00: RxData <= {RxData[DATA_WIDTH-2:0], MISO};
        2'b01, 
        2'b10: begin
                 txreg <= {txreg[DATA_WIDTH-2:0], 1'b0};
                 MOSI <= txreg[DATA_WIDTH-1];
               end
        2'b11: RxData <= {RxData[DATA_WIDTH-2:0], MISO};
        default: ;
      endcase

// Handles the falling edge of SClk for all 4 SPI modes
    always @ (negedge SClk)
      case ( {ClkPol, ClkPha} )
        2'b00: begin
                 txreg <= {txreg[DATA_WIDTH-2:0], 1'b0};
                 MOSI <= txreg[DATA_WIDTH-1];
               end
        2'b01, 
        2'b10: RxData <= {RxData[DATA_WIDTH-2:0], MISO};
        2'b11: begin
                 txreg <= {txreg[DATA_WIDTH-2:0], 1'b0};
                 MOSI <= txreg[DATA_WIDTH-1];
               end
        default: ;
      endcase

endmodule