`timescale 1ns / 1ps

module SPI_master_tb ();

  reg        Clk;
  reg        Reset;
  reg        Start;
  reg  [7:0] TxData_m;
  wire [7:0] RxData_m;
  reg  [7:0] TxData_s;
  wire [7:0] RxData_s;

  wire       SClk;
  wire       MISO;
  wire       MOSI;
  wire       SS;

  wire       Done;
  wire       SlvDone;

  event      trigger_reset;
  event      reset_complete;

  event      assert_start;
  event      deassert_start;

  spi_master #(.DATA_WIDTH(8), .SPI_MODE(3))
              master  (
                      .Clk    (Clk),
                      .Reset  (Reset),
                      .Start  (Start),
                      .ClkDiv (2'b01),
                      .TxData (TxData_m[7:0]),
                      .Done   (Done),
                      .RxData (RxData_m[7:0]),
                      // SPI Interface
                      .MISO   (MISO),
                      .SClk   (SClk),
                      .MOSI   (MOSI),
                      .SS     (SS)
                      );

  spi_slave #(.DATA_WIDTH(8), .SPI_MODE(3))
              slave   (
                      .TxData (TxData_s[7:0]),
                      .Done   (SlvDone),
                      .RxData (RxData_s[7:0]),
                      // SPI Interface
                      .MISO   (MISO),
                      .SClk   (SClk),
                      .MOSI   (MOSI),
                      .SS     (SS)
                      );
    initial
      begin
        Clk      <= 1'b0;
        Reset    <= 1'b0;
        Start    <= 1'b0;
        TxData_m <= 8'b0;

        #30;
        -> trigger_reset;

        @(reset_complete);

        #60;
        TxData_m <= 8'b1010_0101;
        TxData_s <= 8'b1101_0110;

        -> assert_start;
        @(deassert_start);
        #1500;

        repeat (10) begin
          TxData_m <= $unsigned($random) % 255;
          TxData_s <= $unsigned($random) % 255;

          -> assert_start;
          @(deassert_start);
          #1500;
        end
      end

    initial
      begin: RESET_LOGIC
        forever begin 
          @ (trigger_reset); 
          @ (negedge Clk); 
          Reset = 1; 
          @ (negedge Clk); 
          Reset = 0; 
          -> reset_complete; 
        end
      end

    initial
      begin: PULSE_START
        forever begin 
          @ (assert_start); 
          @ (negedge Clk); 
          Start = 1; 
          @ (negedge Clk); 
          Start = 0; 
          -> deassert_start; 
        end
      end

    always @ (*)
      Clk <= #10 ~Clk;

endmodule