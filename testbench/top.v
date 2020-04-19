`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   01:20:48 04/16/2020
// Design Name:   master
// Module Name:   D:/VerilogFiles/i2c/top.v
// Project Name:  i2c
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: master
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module top; 

	// Inputs
	
	reg clk2=0;
	reg start;
	reg stop;
 
	reg reset;

  	reg dataBusEnable;
	reg[7:0] dataBus1;
	reg[7:0] dataBus_s1;
	reg dataBus_sEnable;
	wire scl;
	// Bidirs
	wire sda;
	wire [7:0] dataBus;
   
	wire[7:0] dataBus_s;



	// Instantiate the Unit Under Test (UUT)
	master uut2 (
		.clk(clk2), 
		.scl(scl),  
		.start(start), 
		.stop(stop), 
		.reset(reset), 
		.sda(sda), 
		.dataBus(dataBus)
		
		
		
	);
		slave uut (  
    	.reset(reset), 
		.start(start),  
		.dataBus_s(dataBus_s), 
		.sda(sda),		
		.scl(scl)
	);

	initial begin
	reset=1;    dataBusEnable=0; //asynchronous resets master and slave at this instant
      #1 reset=0; 
		#1 start=1;/*master goes to start state in the next posedge of clk1*/ dataBusEnable=1; dataBus1=8'b10010101; 
		//here 1001010 is the 7 bit slave address and lsb 1 means read operation,i.e, slave with address 1001010 will
		//send the data to the master
      #20 start=0; dataBusEnable=0;   
		#325.5
		#10.5  
		#6  dataBus_sEnable=1; dataBus_s1=8'b1010_0110; //loading slave with data to be sent to master
		#315  dataBus_s1=8'b1110_0100;// loading slave with another byte of data to be sent to the master
		 
	end     
	//code for generating clock signal
   always #2.5 clk2=~clk2; 
	initial $display("clk2=%b",clk2);

	assign dataBus=(dataBusEnable)?(dataBus1):(8'bzzzz_zzzz);
	assign dataBus_s=(dataBus_sEnable)?(dataBus_s1):(8'bZ);
endmodule

