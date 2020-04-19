`timescale 1ns / 1ps

module mode8counter(
    input clk2,reset,
    output  clk1
    );
	 reg[2:0] count;
	 always@(negedge clk2,posedge reset)begin
	 if(reset)
	 count<=0;
	 else count<=count+1;
	 end
	 assign clk1=(count[2]==1);


endmodule
  