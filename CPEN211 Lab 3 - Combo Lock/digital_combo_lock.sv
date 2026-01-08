/*
  CPEN 211 Lab 3

  Author: Edan Steen
  Date: October 17, 2024
*/

// FSM State definitions
`define INITIAL 7'b0000000 //the initial state.

`define GOOD_INPUT1 7'b0000010
`define GOOD_INPUT2 7'b0000100
`define GOOD_INPUT3 7'b0001000
`define GOOD_INPUT4 7'b0010000
`define GOOD_INPUT5 7'b0100000
`define OPEN 7'b1000000 //OPEN!!
  
`define BAD_INPUT1 7'b0000011
`define BAD_INPUT2 7'b0000101
`define BAD_INPUT3 7'b0001001
`define BAD_INPUT4 7'b0010001
`define BAD_INPUT5 7'b0100001
`define CLOSED 7'b1000001 //CLOSED!!

`define ERROR 7'bxxxxxxx //ERROR. Inputs don't represent digit (0-9) or something else bad happened

// NUMBERS ON 7-SEG DISPLAY (0 = on, 1 = off)
`define DISPLAY_0 7'b1000000
`define DISPLAY_1 7'b1000000 
`define DISPLAY_1 7'b1111001  
`define DISPLAY_2 7'b0100100 
`define DISPLAY_3 7'b0110000 
`define DISPLAY_4 7'b0011001 
`define DISPLAY_5 7'b0010010 
`define DISPLAY_6 7'b0000010 
`define DISPLAY_7 7'b1111000 
`define DISPLAY_8 7'b0000000 //for 8 all leds are on
`define DISPLAY_9 7'b0010000 

// LETTERS ON 7-SEG DISPLAY (OPEn, CLOSEd, ErrOr)
`define DISPLAY_O 7'b1000000 //same as 0
`define DISPLAY_P 7'b0001100 
`define DISPLAY_E 7'b0000110 
`define DISPLAY_N 7'b0101011 //lowercase n
`define DISPLAY_C 7'b1000110 
`define DISPLAY_L 7'b1000111 
`define DISPLAY_S 7'b0010010 //same as 5 
`define DISPLAY_D 7'b0100001 //lowercase d
`define DISPLAY_R 7'b0101111 //lowercase r
`define CLEAR 7'b1111111 //turn all leds off

module lab3_top(SW,KEY,HEX0,HEX1,HEX2,HEX3,HEX4,HEX5,LEDR);
  input [9:0] SW; 
  input [3:0] KEY;
  output wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
  output [9:0] LEDR;   // optional: use these outputs for debugging on your DE1-SoC

  wire clk = ~KEY[0];  // this is your clock
  wire rst_n = KEY[3]; // this is your reset; your reset should be synchronous and active-low

  wire [3:0] switch_inputs = SW[3:0]; //the switches used as inputs

  reg [6:0] pres_state;

  lab3_decoder Decoder (switch_inputs, pres_state, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5);

  //Always block for registering clock inputs
  always_ff @( posedge clk ) begin
    // when the reset is pressed, reset to initial state
    if (!rst_n)
      pres_state = `INITIAL;

    //if reset is not pressed, check the inputs
    else
      //check the inputs of SW
      case (pres_state) // REMEMBER CODE IS 8 9 1 0 1 3
        `INITIAL : if (switch_inputs === 8) pres_state = `GOOD_INPUT1;
                   else pres_state = `BAD_INPUT1;
        `GOOD_INPUT1 : if (switch_inputs === 9) pres_state = `GOOD_INPUT2;
                       else pres_state = `BAD_INPUT2;

        `GOOD_INPUT2 : if (switch_inputs === 1) pres_state = `GOOD_INPUT3;
                       else pres_state = `BAD_INPUT3;
        
        `GOOD_INPUT3 : if (switch_inputs === 0) pres_state = `GOOD_INPUT4;
                       else pres_state = `BAD_INPUT4;
        
        `GOOD_INPUT4 : if (switch_inputs === 1) pres_state = `GOOD_INPUT5;
                       else pres_state = `BAD_INPUT5;
        
        `GOOD_INPUT5 : if (switch_inputs === 3) pres_state = `OPEN;
                       else pres_state = `CLOSED;

        `BAD_INPUT1: pres_state = `BAD_INPUT2;
        `BAD_INPUT2: pres_state = `BAD_INPUT3;
        `BAD_INPUT3: pres_state = `BAD_INPUT4;
        `BAD_INPUT4: pres_state = `BAD_INPUT5;
        `BAD_INPUT5: pres_state = `CLOSED;
        
        `OPEN, `CLOSED: pres_state = pres_state; //do nothing, user can only reset

        default: pres_state = `ERROR; //ANYTHING ELSE IS AN ERROR
      endcase
  end
endmodule

module lab3_decoder(switch_inputs, present_state, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5);
  input [3:0] switch_inputs;
  input [6:0] present_state;
  
  output [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;

  reg [6:0] present_state;
  reg [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
  
  always_comb begin
    //clear HEX1-HEX5
    // IMPORTANT THAT THESE ARE NON-BLOCKING SINCE THEY CAN CHANGE RIGHT AFTER
    HEX1 <= `CLEAR; HEX2 <= `CLEAR; HEX3 <= `CLEAR; HEX4 <= `CLEAR; HEX5 <= `CLEAR;

    case (present_state)
      `INITIAL, `GOOD_INPUT1, `GOOD_INPUT2, `GOOD_INPUT3, `GOOD_INPUT4, `GOOD_INPUT5, 
      `BAD_INPUT1, `BAD_INPUT2, `BAD_INPUT3, `BAD_INPUT4, `BAD_INPUT5:
        //display whatever number the switches show on HEX0  
        case (switch_inputs)
          0: HEX0 <= `DISPLAY_0;
          1: HEX0 <= `DISPLAY_1;
          2: HEX0 <= `DISPLAY_2;
          3: HEX0 <= `DISPLAY_3;
          4: HEX0 <= `DISPLAY_4;
          5: HEX0 <= `DISPLAY_5;
          6: HEX0 <= `DISPLAY_6;
          7: HEX0 <= `DISPLAY_7;
          8: HEX0 <= `DISPLAY_8;
          9: HEX0 <= `DISPLAY_9;
          default: begin // anything else is an error!!
            HEX4 <= `DISPLAY_E;
            HEX3 <= `DISPLAY_R;
            HEX2 <= `DISPLAY_R;
            HEX1 <= `DISPLAY_O;
            HEX0 <= `DISPLAY_R;
          end
        endcase

      `OPEN: begin
        HEX3 <= `DISPLAY_O;
        HEX2 <= `DISPLAY_P;
        HEX1 <= `DISPLAY_E;
        HEX0 <= `DISPLAY_N;
      end

      `CLOSED: begin
        HEX5 <= `DISPLAY_C;
        HEX4 <= `DISPLAY_L;
        HEX3 <= `DISPLAY_O;
        HEX2 <= `DISPLAY_S;
        HEX1 <= `DISPLAY_E;
        HEX0 <= `DISPLAY_D;
      end

      default: begin // anything else is an error!!
        HEX4 <= `DISPLAY_E;
        HEX3 <= `DISPLAY_R;
        HEX2 <= `DISPLAY_R;
        HEX1 <= `DISPLAY_O;
        HEX0 <= `DISPLAY_R;
      end
    endcase
  end
endmodule
