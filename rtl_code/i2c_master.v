`timescale 1ns / 1ps
module master(input clk,start,stop,reset,inout sda,scl,inout[7:0] dataBus,output reg scl_enable);
// datBus: It is the 1 byte bidirectional databus which sends data to be sent serially to the slave via sda
//start: master is in idle state. When start signal is asserted, master comes in start state in the next positive edge of scl
//(serial clock)
//sda: It is serial data line which is bidirectional in nature.
//reset: It resets the master and brings it to idle state. It is asynchronous signal.
	
// defining states for FSM
parameter
s_idle = 4'd0,
s_start=4'd1,
s_address=4'd2,
s_ack_detection=4'd3,
s_read=4'd4,
s_send_ack=4'd5,
s_send_nack=4'd6,
s_write=4'd7,
s_detect_ack=4'd8,
s_repstart=4'd9,
s_stop=4'd10; 

reg[3:0] c_state,n_state; //currentState and nextState of FSM

//freq of scl is 8 times greater than clk1
// both preset and reset are synchronous and change transmitReg[7]
reg sendStart,sendStop,serialDataBus,oe_sda,oe_db,shiftTR,loadTR,receiveData,preset,clear;
wire ackGot,clk1;
//internal registers
reg[2:0] c2,c3;
reg[7:0] c1,transmitReg,receiveReg;
reg incC2,incC1,incC3,resetC1,resetC2,resetC3;
assign sda=(oe_sda)?(serialDataBus):(1'bz);
assign ackGot=(receiveReg[0]==0);
assign dataBus=(oe_db)?(receiveReg):(8'bZ);
//////////defining bidirectional clock here////////////////
assign scl=(scl_enable)?(clk):(1'bz);
always@(posedge clk) begin
if((scl==='bx)||(~scl&clk))
scl_enable=0;
else 
scl_enable=1;
end
mode8counter m(scl,reset,clk1);
//c2 counter is used for reading and writing purpose and to send slave address
//c3 counter is used for generating stop and start condition
///////////////to generate start condition////////////
////////////to generate stop condition//////////
/////////code to send data serially via dataBus/////////
always@(posedge scl,posedge reset) begin
if(reset)
serialDataBus<=1;

else begin

if(clk1&&(c3=='d2)) begin
if(sendStop)
serialDataBus<=1'b1;
else if(sendStart)
serialDataBus<=1'b0;
end

if((~clk1)&&(c2=='d1)) 
if(shiftTR)
serialDataBus<=transmitReg['d7-c1];

end


end
///////////code to increment c3 when incC3=1 and posedge scl occurs
always@(posedge scl) begin
if ((resetC3|reset)&~clk1)
c3<=0;
else if(incC3)
c3<=c3+1;
end


//////////////////synchronous resets/////////////
always@(posedge clk1) begin
if(resetC1|reset)
c1<=0;

else if(incC1)
c1<=c1+1;
end
/////////to load transmitReg at posedge of clk1 if loadTR==1///////
always@(posedge clk1) begin
if(preset)
transmitReg[7]<=1'b1;
else if(clear)
transmitReg[7]<=1'b0;
else if(loadTR)
transmitReg<=dataBus;
end

//////////to read from sda and place the data into receiveReg at posedge scl when clk1==0 and c2=='d2//////////
always@(posedge scl) begin
if(~clk1 && c2=='d3) 
if(receiveData)
receiveReg<={receiveReg[6:0],sda};
end

///////////code to increment c2 counter when posedge scl occurs and and clk1==0////////////
always@(posedge scl) begin
if ((resetC2|reset)&clk1)
c2<=0;
else if(~clk1&&incC2)
c2<=c2+1;
end

//code for deciding next state of FSM and output signals of FSM
always@(*) begin
sendStart=0; sendStop=0; incC3=0; incC2=0; incC1=0; resetC1=0; resetC2=0; resetC3=0; shiftTR=0;
loadTR=0; receiveData=0;preset=0; clear=0;
case(c_state)
s_idle: begin
         if(start)begin n_state=s_start;
			               resetC3=1;
                        loadTR=1;	
								resetC1=1;
			         end
			else n_state=s_idle;
		  end
s_start: begin
              incC3=1; sendStart=1; incC1=1;resetC2=1; incC2=1; shiftTR=1;
				  n_state=s_address;  
				  
         end
s_address:begin    resetC2=1; incC1=1; incC2=1; shiftTR=1;
                   if(c1=='d7) begin n_state=s_ack_detection;
						 //resetC2=1;
						 end
						 else begin resetC2=1;
						            n_state=s_address;
						 end

          end
s_ack_detection:begin resetC2=1;
                    incC2=1; receiveData=1;
						  if(ackGot) begin
						  if(transmitReg[0]) begin//rw==1 means perform read operation
						  resetC1=1;  n_state=s_read;
						  end
						  else begin
						  resetC1=1;
						  loadTR=1;
						  n_state=s_write;
						  end
						  end
						  else
						  n_state=s_idle;
					 end
s_read:  begin resetC2=1; incC2=1; incC1=1; receiveData=1;
               if(c1!='d7) 
					n_state=s_read;				
					else begin
					resetC1=1;
					loadTR=1; 
					if(stop) begin
					n_state=s_send_nack;
					preset=1;
					end
					else begin
					n_state=s_send_ack;
					clear=1;
					end
					end
         end
s_send_ack:begin incC2=1;
                  resetC2=1;
                 shiftTR=1;
					  n_state=s_read;
           end
s_send_nack:begin incC2=1; shiftTR=1;
						resetC2=1;
						resetC3=1; 
						n_state=s_repstart;
            end
s_write:begin  resetC2=1; incC2=1; incC1=1; shiftTR=1;
					if(c1=='d7) begin
					n_state=s_detect_ack;
					end
					else begin
					resetC2=1;
					n_state=s_write;
					end
         end
s_detect_ack:begin resetC2=1; incC2=1; receiveData=1;
						 if(ackGot) begin
						 if(stop) begin
						 resetC3=1;
						 n_state=s_stop;
						 end
						 else begin
						 resetC1=1;
						 resetC2=1;
						 loadTR=1;
						 n_state=s_write;
						 end					 
						 end
						 else begin
						 resetC1=1;
						 resetC2=1;
						 loadTR=0;
						 n_state=s_write;
						 end
              end
s_repstart: begin
              incC3=1; sendStart=1; 
				  n_state=s_idle;  
				  
            end
s_stop: begin incC3=1; sendStop=1;						
				  n_state=s_idle;
	   	end
default: n_state=s_idle;
endcase 
end


always@(posedge clk1, posedge reset) begin
if(reset)
c_state<=s_idle;
else
c_state<=n_state;
end

//oe_sda: When deasserted master tristates the serial data line(sda). When asserted master sends the data via serial data line.
//oe_db: When asserted master can send the eight bit data(received from slave) to the bidirectional eight bit data bus.
always@(*) begin
oe_db=0; oe_sda=0; 
case(c_state) 
s_idle:begin oe_db=0; oe_sda=0; end
s_start:begin oe_sda=1; oe_db=1; end
s_address:begin oe_sda=1; oe_db=0; end
s_ack_detection:begin oe_db=0; oe_sda=0; end
s_read:begin oe_db=0; oe_sda=0; end
s_send_ack:begin oe_sda=1; oe_db=1;end
s_send_nack:begin oe_sda=1; oe_db=1;end
s_write:begin oe_sda=1; oe_db=0; end
s_detect_ack:begin oe_db=0; oe_sda=0; end
s_stop: begin oe_db=0; oe_sda=1;end
s_repstart: begin oe_db=0; oe_sda=1;end
default: begin oe_db=0; oe_sda=0;  end
endcase
end

//tested start condition working fine
//tested stop condition working fine
//writing slave address working fine
//reading acknowledgement after sending address working fine
//sending data via serial data bus working fine

endmodule
