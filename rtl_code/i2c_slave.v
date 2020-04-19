`timescale 1ns / 1ps
module slave #(localparam myAddress='b1001010)(input reset,start,inout[7:0] dataBus_s,
               inout sda,inout scl);
wire clk1;
reg serialdataBus_s1,oe_sda,oe_db;
assign dataBus_s=(oe_db)?(receiveReg):(8'bZ);
assign sda=(oe_sda)?(serialdataBus_s1):(1'bz);
parameter s_idle='d0,
			 s_active='d1,
			 s_read_address='d2,
			 s_read_message='d3,
			 s_send_nack='d4,
			 s_send_ack='d5,
			 s_stop_detection='d6,
			 s_start_detection='d7,
			 s_send_message='d8,
			 s_ack_detection='d9,
/*correction new state added*/ s_ack_address='d10;
//internal signals used
mode8counter m(scl,reset,clk1);

reg sdetect,resetC3,incC3,resetC2,incC2,resetC1,incC1,receiveData,shiftTR,
	 loadTR,clear,preset,discrepency,stopDetected,startDetected;
wire lsb,ackGot;
//registers used
//reg[3:0] sdetector; // 4bit register used to detect start and stop condition during positive edge of clk
reg[7:0] transmitReg,receiveReg; // 8 bit registers for transmiting and receiving  data serially via sda
reg[2:0] c2,c3,c1;
reg[3:0] i,sdetector;

assign lsb=receiveReg[0];
assign ackGot=(receiveReg[0]==1'b0);
reg[3:0] c_state,n_state;//states for fsm
//////////////checking if the data received via sda is valid or not//////////////////////
always@(*) begin
for(i=0;i<=7;i=i+1) begin
if((receiveReg[i]==1'bz)||(receiveReg[i]==1'bx)) begin
discrepency=1;
end
end
end


///////////////code for detecting start and stop condition////////////////////
always@(posedge scl) begin
if(clk1&&sdetect)
sdetector['d3-c3]<=sda;
end
always@(*) begin
startDetected=0; stopDetected=0;
case(sdetector)
'b1000:startDetected=1;
'b1100:startDetected=1;
'b1110:startDetected=1;
'b0111:stopDetected=1;
'b0011:stopDetected=1;
'b0001:stopDetected=1;
default:begin  startDetected=0; stopDetected=0; end
endcase
end

///////////code for receiving data serially via sda//////////////
always@(posedge scl) begin
if((~clk1)&&(c2=='d3))
if(receiveData)
receiveReg<={receiveReg[6:0],sda};
end

/////////////code for sending data serially via sda/////////////////
always@(posedge clk1) begin
if(preset)
transmitReg[7]<=1;
else if(clear)
transmitReg[7]<=0;
else if(loadTR)
transmitReg<=dataBus_s;
end

always@(posedge scl) begin
if((~clk1)&&c2=='d1)
if(shiftTR)
serialdataBus_s1<=transmitReg['d7-c1];
end
//////////////counters//////////////
always@(posedge clk1) begin
if(resetC1)
c1<=0;
else if(incC1)
c1<=c1+1;
end

always@(posedge scl) begin
if(resetC2&&clk1)
c2<=0;
else if(~clk1&&incC2)
c2<=c2+1;
end

always@(posedge scl) begin
if(resetC3&&(~clk1))
c3<=0;
else if(clk1&&incC3)
c3<=c3+1;
end

always@(posedge clk1,posedge reset) begin
if(reset)
c_state<=s_idle;
else 
c_state<=n_state;
end


always@(*) begin
resetC3=0; incC3=0; resetC1=0; incC1=0; resetC2=0; incC2=0; receiveData=0; sdetect=0; clear=0; 
preset=0; shiftTR=0; loadTR=0;	
case(c_state)
s_idle: if(start) begin
			n_state=s_active;
			resetC3=1;
			resetC1=1;
		  end
		  else 
		  n_state=s_idle;
s_active: begin  resetC2=1; incC2=1; receiveData=1; sdetect=1; incC3=1;
				 if(startDetected) begin
				    n_state=s_read_address;
					 incC1=1;
				 end
				 else begin
				 resetC3=1;
				 n_state=s_active;
				 end
				 
			 end

s_read_address: begin resetC2=1; incC2=1; receiveData=1; incC1=1;
						    if(c1=='d7&&receiveReg[7:1]==myAddress) begin
							   clear=1;
								n_state=s_ack_address;
							 end
							 else if(c1=='d7&&receiveReg[7:1]!=myAddress) 							 
							 n_state=s_active;
							 
							 else
							 n_state=s_read_address;
							 
                end
s_ack_address: begin
                 incC2=1; resetC2=1; shiftTR=1;
					  if(lsb) begin
					  resetC1=1;
					  loadTR=1;
					  n_state=s_send_message;
					  end
					  else begin
					  resetC1=1;
					  n_state=s_read_message;
					  end
					end
s_read_message: begin
                   resetC2=1; incC2=1; receiveData=1; incC1=1;
						 
						 if(c1=='d7) begin
						 
						 if(discrepency) begin
						 preset=1;
						 n_state=s_send_nack;
						 end
						
     					 else begin
						 clear=1;
						 n_state=s_send_ack;
						 end						 
						 
						 end
						 
						 else 
						 n_state=s_read_message;						 
                end

s_send_nack: begin
					resetC2=1; incC2=1; shiftTR=1;
					resetC1=1;
					n_state=s_read_message;
             end
s_send_ack: begin
					resetC2=1; incC2=1; shiftTR=1; resetC3=1; resetC1=1;
					n_state=s_stop_detection;
            end
s_stop_detection: begin
                     resetC2=1; incC3=1; sdetect=1;
							if(stopDetected) 							
							n_state=s_idle;
							
							else begin
							incC1=1; receiveData=1; incC2=1;
							n_state=s_read_message;
							end
                  end
s_send_message: begin
                  resetC2=1; incC1=1; incC2=1; shiftTR=1;
						if(c1!='d7)
						n_state=s_send_message;
						else
						n_state=s_ack_detection;
					 end
s_ack_detection: begin
                    resetC2=1; incC2=1; receiveData=1;
						  if(ackGot)begin n_state=s_send_message;
						  resetC1=1;
						  loadTR=1;
						  end
						  else begin
						  resetC3=1;
						  resetC1=1;
						  n_state=s_start_detection;
						  end
						  
                 end	
s_start_detection: begin
							resetC2=1; incC3=1; sdetect=1;
							if(startDetected) 							
							n_state=s_idle;
							
							
							else begin
							incC2=1;
							shiftTR=1;
							incC1=1;
							n_state=s_send_message;
							end
                   end		
default: n_state=s_idle;						 
endcase
end


always@(*) begin
oe_db=0; oe_sda=0;
case(c_state)
s_send_nack:begin  oe_db=1; oe_sda=1;end
s_send_ack: begin oe_db=1; oe_sda=1; end
s_send_message:oe_sda=1;
s_ack_address:oe_sda=1;
default: begin oe_db=0; oe_sda=0; end
endcase
end





endmodule
