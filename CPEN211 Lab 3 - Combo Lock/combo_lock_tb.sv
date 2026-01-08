/*
    Pre-Synthesis Testbench Code

    Author: Edan Steen
    Date: October 18, 2024
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

module tb_lab3();
    //Used for Full DUT
    reg [3:0] KEY;
    reg [9:0] SW; //note that we only look at keys 0->3
    wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5; 
    wire [9:0] LEDR; //we don't care about these really...
    reg error;
    
    lab3_top DUT(SW,KEY,HEX0,HEX1,HEX2,HEX3,HEX4,HEX5,LEDR);

    reg [6:0] present_state; //so we can view the state in the wave viewer
    reg clk = ~KEY[0];
    reg reset = KEY[3];


    //Test the full device altogether
    task test_full;
        input [6:0] expected_state;
        input [6:0] expected_HEX5, expected_HEX4, expected_HEX3, 
                    expected_HEX2, expected_HEX1, expected_HEX0;

        begin
            present_state = tb_lab3.DUT.pres_state; 
            if (tb_lab3.DUT.pres_state !== expected_state) begin
                $display("ERROR! State is %b, expected %b", tb_lab3.DUT.pres_state, expected_state);
                error = 1'b1;
            end
            if (tb_lab3.DUT.HEX0 !== expected_HEX0) begin
                $display("ERROR! HEX0 is %b, expected %b", tb_lab3.DUT.HEX0, expected_HEX0);
                error = 1'b1;
            end
            if (tb_lab3.DUT.HEX1 !== expected_HEX1) begin
                $display("ERROR! HEX1 is %b, expected %b", tb_lab3.DUT.HEX1, expected_HEX1);
                error = 1'b1;
            end
            if (tb_lab3.DUT.HEX2 !== expected_HEX2) begin
                $display("ERROR! HEX2 is %b, expected %b", tb_lab3.DUT.HEX2, expected_HEX2);
                error = 1'b1;
            end
            if (tb_lab3.DUT.HEX3 !== expected_HEX3) begin
                $display("ERROR! HEX3 is %b, expected %b", tb_lab3.DUT.HEX3, expected_HEX3);
                error = 1'b1;
            end
            if (tb_lab3.DUT.HEX4 !== expected_HEX4) begin
                $display("ERROR! HEX4 is %b, expected %b", tb_lab3.DUT.HEX4, expected_HEX4);
                error = 1'b1;
            end
            if (tb_lab3.DUT.HEX5 !== expected_HEX5) begin
                $display("ERROR! HEX5 is %b, expected %b", tb_lab3.DUT.HEX5, expected_HEX5);
                error = 1'b1;
            end
        end

    endtask

    //Initial block for the clock
    initial begin
        KEY[0] = 0; #5;

        forever begin
            KEY[0] = 1; #5;
            KEY[0] = 0; #5; 
        end
    end

    //Initial block for testing the full machine
    initial begin
        KEY[3] = 1'b0; SW = 4'b000; error = 1'b0; 
        #10;

        test_full(`INITIAL, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `DISPLAY_0);
        KEY[3] = 1'b1; SW = 4'b1000; #10;
        //First testing if the correct combination works  

        test_full(`GOOD_INPUT1, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `DISPLAY_8);
        SW = 4'b1001; #10;

        test_full(`GOOD_INPUT2, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `DISPLAY_9);
        SW = 4'b0001; #10;

        test_full(`GOOD_INPUT3, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `DISPLAY_1);
        SW = 4'b0000; #10;

        test_full(`GOOD_INPUT4, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `DISPLAY_0);
        SW = 4'b0001; #10;

        test_full(`GOOD_INPUT5, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `DISPLAY_1);
        SW = 4'b0011; #10;

        test_full(`OPEN, `CLEAR, `CLEAR, `DISPLAY_O, `DISPLAY_P, `DISPLAY_E, `DISPLAY_N);
        
        SW = 4'b0111; KEY[3] = 1'b0; #20; //reset

        //testing if wrong combination works 
        test_full(`INITIAL, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `DISPLAY_7);
        SW = 4'b0110; KEY[3] = 1'b1; #10;       
         
        test_full(`BAD_INPUT1, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `DISPLAY_6);
        SW = 4'b0101; #10;

        test_full(`BAD_INPUT2, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `DISPLAY_5);
        SW = 4'b1111; #10;

        test_full(`BAD_INPUT3, `CLEAR, `DISPLAY_E, `DISPLAY_R, `DISPLAY_R, `DISPLAY_O, `DISPLAY_R); // error still should go through
        SW = 4'b0010; #10;

        test_full(`BAD_INPUT4, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `DISPLAY_2);
        SW = 4'b0011; #10;

        test_full(`BAD_INPUT5, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `CLEAR, `DISPLAY_3);
        SW = 4'b0011; #10;

        test_full(`CLOSED, `DISPLAY_C, `DISPLAY_L, `DISPLAY_O, `DISPLAY_S, `DISPLAY_E, `DISPLAY_D);

        if (~error) $display("DEVICE PASSED");
        else $display("DEVICE FAILED");

        $stop;
    end
endmodule: tb_lab3
