`include "LAGARTO_CONFIG.v"

module BIMODAL_PREDICTOR(
input 				Stall_FETCH,
input 				Stall_EXE,
input				RST,
input 				CLK,
input 				if_branch_DEC,
input 				if_branch_EX,

input 	`ADDR		EXE_BRANCH_TARGET,		
input 	`ADDR		EXE_Branch_Result,	  

input 	`ADDR		FETCH_PC,
input 	`ADDR		DEC_PC,
input 	`ADDR		RR_PC,
input 	`ADDR		EXE_PC,

output 	`ADDR		PREDICTOR_BRANCH_TARGET,
output 				PREDICTOR_HIT,
output 				PREDICT,
output 	[1:0]		PREDICTOR_TNT
);

wire 		[27:0]	PREDICTOR_DEC_BIPC;
wire 		[27:0]	PREDICTOR_EXE_BIPC;

wire 				HAS_HISTORY;
wire 		[1:0]	EXE_TNT;
wire 		[1:0]	NEXT_STAGE;

wire		`ADDR	PREDICTOR_EXE_TARGET;
wire		`ADDR	DEC_BRANCH_TARGET;
wire		`ADDR	PREDICTOR_BRANCH_RESULT;

wire		`ADDR	NEXT_PC;
//There is no reason to do our life that hard. Please be kind
PatternHistoryTable PHT(CLK,Stall_FETCH,Stall_EXE,RST,if_branch_EX,NEXT_STAGE[1:0],FETCH_PC[11:2],RR_PC[11:2],EXE_PC[11:2],PREDICTOR_TNT[1:0],EXE_TNT[1:0]);
MaquinaEstados MaqEdo(
if_branch_EX,
EXE_TNT[1:0],
PREDICTOR_HIT,
NEXT_STAGE[1:0]);

BranchTargetBuffer BTB(
CLK,
`ifdef SRAM_MEMORIES
RSTaken_branch_EXET,
`endif
Stall_FETCH,
Stall_EXE,
if_branch_EX,
FETCH_PC[11:2],
RR_PC[11:2],
EXE_PC[11:2],
EXE_BRANCH_TARGET,
DEC_BRANCH_TARGET,
PREDICTOR_EXE_TARGET
);

BranchInstPC BIP(CLK,Stall_FETCH,Stall_EXE,RST,HAS_HISTORY,FETCH_PC[11:2],RR_PC[11:2],EXE_PC[11:2],EXE_PC[39:12],if_branch_EX,PREDICTOR_DEC_BIPC,PREDICTOR_EXE_BIPC);
Comparador  COMP1(if_branch_DEC,PREDICTOR_DEC_BIPC,DEC_PC[39:12],PREDICT);
Comparador  COMP2(if_branch_EX,PREDICTOR_EXE_BIPC,EXE_PC[39:12],HAS_HISTORY);


assign 		PREDICTOR_BRANCH_TARGET = DEC_BRANCH_TARGET;
assign      NEXT_PC = EXE_PC+40'h0000000004;
assign 		PREDICTOR_BRANCH_RESULT = (EXE_TNT[1]) ? PREDICTOR_EXE_TARGET: NEXT_PC ;
assign 		PREDICTOR_HIT = (EXE_Branch_Result == PREDICTOR_BRANCH_RESULT);


endmodule


module BranchInstPC(
input clk,
input Stall_FETCH,
input Stall_EXE,
input rst,
input existe,
input [9:0]addressFETCH,addressRR_EXE,
input [9:0]addressEXE,
input [27:0]dat_write,
input ifbranch,
output [27:0]outaddressDEC,outaddressEXE
);

wire write;
assign write = (existe==0 && ifbranch==1); //Si fue un branch y no acerto guardamos la direccion correcta del salto

MEM_BIPC MEM_BIPC_0(
	 .clk(clk),
	 .Stall(Stall_FETCH),
	 .rst(rst),
	 .write(write),
	 .write_address(addressEXE),
	 .write_data(dat_write),
	 .read_address(addressFETCH),
	 .read_data(outaddressDEC)
);

MEM_BIPC MEM_BIPC_1(
	 .clk(clk),
	 .Stall(Stall_EXE),
	 .rst(rst),
	 .write(write),
	 .write_address(addressEXE),
	 .write_data(dat_write),
	 .read_address(addressRR_EXE),
	 .read_data(outaddressEXE)
);

endmodule


module MEM_BIPC(
	input clk,
	input Stall,
	input rst,
	input write,
	input [9:0] write_address,
	input [27:0]write_data,
	input [9:0] read_address,
`ifndef SRAM_MEMORIES
	output reg [27:0] read_data
`else
	output [27:0] read_data
`endif
);

`ifndef SRAM_MEMORIES

reg [27:0]Memoria[0:1023]; 

`ifndef SYNTHESIS
integer i;
initial 
begin
for(i=0; i<1024 ; i=i+1)
	Memoria[i] = 28'hFFFFFFF;
end
`endif

always@(posedge clk)
begin
	if(~rst)
	read_data<=28'hFFFFFFF;
		else	if(Stall == 1'b0)
				read_data <= Memoria[read_address];
end
	
always@(posedge clk)
begin 
	if(write) 
		Memoria[write_address]<=write_data; 
end

`else // If SRAM memories are used

wire [27:0] aux_read_data;
wire [9:0] aux_read_address;

reg [27:0] aux_data;
reg same_address, same_address_aux;

always @(*) begin
  if ((write_address == read_address) && write)
    same_address <= 1'b1;
  else
    same_address <= 1'b0;
end

always @(posedge clk) begin
  if(~rst) begin
    aux_data <= 28'b0;
    same_address_aux <= 1'b0;
  end
  else begin
    if(same_address)
      aux_data <= write_data;
    same_address_aux <= same_address;
  end
end

assign aux_read_address = same_address ? 10'h000 : read_address;
assign read_data = same_address_aux ? aux_data : aux_read_data;

reg [27:0] aux_write_data;
always @(posedge clk) begin
  if(~rst)
    aux_write_data <= 28'b0;
  else
    aux_write_data <= write_data;
end
  // Port A: Write; Port B: Read
  TSDN65LPA1024X28M4S BIPCArray (
    .AA  (write_address) ,
    .DA  (aux_write_data) ,
    .BWEBA  (28'b0) ,
    .WEBA  (!write) ,
    .CEBA  (1'b0) ,
    .CLKA  (clk) ,
    .AB  (aux_read_address) ,
    .DB  (28'b0) ,
    .BWEBB  ({28{1'b1}}) ,
    .WEBB  (1'b1) ,
    .CEBB  (Stall) ,
    .CLKB  (clk) ,
    .QB  (aux_read_data) 
    ); // QA output left unconnected
`endif

endmodule




//----------------------------------------------------------------------------------------------------------------------
//	BRANCH TARGET BUFFER
//---------------------------------------------------------------------------------------------------------------------- 

module BranchTargetBuffer(
	input clk,
`ifdef SRAM_MEMORIES
	input rst,
`endif
	input Stall_FETCH,
    input Stall_EXE,
	input ifbranch,
	input [9:0] PCFETCH,PCRR_EX,
	input [9:0] addressEXE,
	input [39:0] dat_write,
	output [39:0] branchTarget,branchTargetEXE
);

wire write;
assign write = (ifbranch==1); 

MEM_BTB MEM_BTB_0(
	 .clk(clk),
`ifdef SRAM_MEMORIES
	 .rst(rst),
`endif
	 .Stall(Stall_FETCH),
	 .write(write),
	 .write_address(addressEXE),
	 .write_data(dat_write),
	 .read_address(PCFETCH),
	 .read_data(branchTarget)
);

MEM_BTB MEM_BTB_1(
	 .clk(clk),
`ifdef SRAM_MEMORIES
	 .rst(rst),
`endif
	 .Stall(Stall_EXE),
	 .write(write),
	 .write_address(addressEXE),
	 .write_data(dat_write),
	 .read_address(PCRR_EX),
	 .read_data(branchTargetEXE)
);

endmodule




module MEM_BTB(
	input clk,
`ifdef SRAM_MEMORIES
    input rst,
`endif
	input Stall,
	input write,
	input [9:0] write_address,
	input [39:0]write_data,
	input [9:0] read_address,
`ifndef SRAM_MEMORIES
	output reg [39:0] read_data
`else
	output [39:0] read_data
`endif
);

`ifndef SRAM_MEMORIES
reg [39:0] Memoria [0:1023];

`ifndef SYNTHESIS
	integer i;
	initial 
	begin
		for(i=0; i<1024 ; i=i+1)
			Memoria[i] = 40'h0000000000;
	end
`endif

always@(posedge clk)
begin
	if(Stall == 1'b0)
		read_data <= Memoria[read_address];
end
	
always@(posedge clk)
begin 
	if(write) 
		Memoria[write_address]<=write_data; 
end

`else

wire [39:0] aux_read_data;
wire [9:0] aux_read_address;

reg [39:0] aux_data;
reg same_address, same_address_aux;

always @(*) begin
  if ((write_address == read_address) && write)
    same_address <= 1'b1;
  else
    same_address <= 1'b0;
end
always @(posedge clk) begin
  if(~rst) begin
    aux_data <= 40'b0;
    same_address_aux <= 1'b0;
  end
  else begin
    if(same_address)
      aux_data <= write_data;
    same_address_aux <= same_address;
  end
end

assign aux_read_address = same_address ? 10'h000 : read_address;
assign read_data = same_address_aux ? aux_data : aux_read_data;

reg [39:0] aux_write_data;
always @(posedge clk) begin
  if(~rst)
    aux_write_data <= 40'b0;
  else
    aux_write_data <= write_data;
end
// Port A: Write; Port B: Read
  TSDN65LPA1024X40M4S BTBArray_1 (
    .AA  (write_address) ,
    .DA  (aux_write_data) ,
    .BWEBA  (40'b0) ,
    .WEBA  (!write) ,
    .CEBA  (1'b0) ,
    .CLKA  (clk) ,
    .AB  (aux_read_address) ,
    .DB  (40'b0) ,
    .BWEBB  ({40{1'b1}}) ,
    .WEBB  (1'b1) ,
    .CEBB  (Stall) ,
    .CLKB  (clk) ,
    .QB  (aux_read_data) 
    ); // QA output left unconnected
`endif

endmodule




//----------------------------------------------------------------------------------------------------------------------
// PATTERN HISTORY TABLE
//---------------------------------------------------------------------------------------------------------------------- 

module PatternHistoryTable(
	input clk,
	input Stall_FETCH,
    input Stall_EXE,
	input rst,
	input ifbranch,
	input [1:0]write_data,
	input [9:0] addressFETCH,addressRR,addressEXE,
	output [1:0] TNT,TNTEXE
);

wire write ;
assign write = ifbranch;

MEM_PHT MEM_PHT_0(
	 .clk(clk),
	 .Stall(Stall_FETCH),
	 .rst(rst),
	 .write(write),
	 .write_address(addressEXE),
	 .write_data(write_data),
	 .read_address(addressFETCH),
	 .read_data(TNT)
);
MEM_PHT MEM_PHT_1(
	 .clk(clk),
	 .Stall(Stall_EXE),
	 .rst(rst),
	 .write(write),
	 .write_address(addressEXE),
	 .write_data(write_data),
	 .read_address(addressRR),
	 .read_data(TNTEXE)
);
endmodule 


module MEM_PHT(
	input clk,Stall,rst,
	input write,
	input [9:0] write_address,
	input [1:0]write_data,
	input [9:0] read_address,
`ifndef SRAM_MEMORIES
	output reg [1:0] read_data
`else
	output [1:0] read_data
`endif
);

`ifndef SRAM_MEMORIES
reg [1:0]Memoria[0:1023]; 
`ifndef SYNTHESIS
	integer i;
	initial 
	begin
	for(i=0; i<1024 ; i=i+1)
		Memoria[i] = 2'b00;
	end
`endif

always@(posedge clk)
begin
	if(~rst)
		read_data <= 2'b00;
	else if(Stall == 1'b0)
		read_data <= Memoria[read_address];
end
	
always@(posedge clk)
begin 
	if(write) 
		Memoria[write_address]<=write_data; 
end

`else
//wire nclk;
//assign nclk = !clk;
wire [1:0] aux_read_data;
wire [9:0] aux_read_address;

reg [1:0] aux_data;
reg same_address, same_address_aux;

always @(*) begin
  if ((write_address == read_address) && write)
    same_address <= 1'b1;
  else
    same_address <= 1'b0;
end
always @(posedge clk) begin
	if(~rst) begin
 		aux_data <= 2'b0;
		same_address_aux <= 1'b0;
	end  
	else begin
		if(same_address)
 			aux_data <= write_data;
		same_address_aux <= same_address;
	end
end

assign aux_read_address = same_address ? 10'h000 : read_address;
assign read_data = same_address_aux ? aux_data : aux_read_data;

reg [1:0] aux_write_data;
always @(posedge clk) begin
	if(~rst)
		aux_write_data <= 2'b0;
	else 	
		aux_write_data <= write_data;
end

// Port A: Write; Port B: Read
  TSDN65LPA1024X2M4S PHTArray (
    .AA  (write_address) ,
    .DA  (aux_write_data) ,
    .BWEBA  (2'b0) ,
    .WEBA  (!write) ,
    .CEBA  (1'b0) ,
    .CLKA  (clk) ,
    .AB  (aux_read_address) ,
    .DB  (2'b0) ,
    .BWEBB  (2'b11) ,
    .WEBB  (1'b1) ,
    .CEBB  (Stall) ,
    .CLKB  (clk) ,
    .QB  (aux_read_data) 
    ); // QA output left unconnected
`endif

endmodule


//----------------------------------------------------------------------------------------------------------------------
// STATE MACHINE
//---------------------------------------------------------------------------------------------------------------------- 

module MaquinaEstados(
	input ifbranch,
	input [1:0] EstadoActual,
	input MissHit,
	output  [1:0] EstadoSiguiente
);

	parameter   Inicio = 3'b100,
				Uno = 3'b101,
				Dos = 3'b110,
				Tres = 3'b111;
				
reg [2:0]Edo_Sgte;
always @(*)
begin
	case ({ifbranch,EstadoActual})
		Inicio: begin
			Edo_Sgte = (MissHit) ? Inicio : Uno;
			end
		Uno: begin
			 Edo_Sgte = (MissHit)? Inicio : Dos;
			end
		Dos: begin
			 Edo_Sgte = (MissHit)? Tres : Uno;
			end
		Tres: begin
			 Edo_Sgte = (MissHit)? Tres : Dos;
			end
		default: begin
			 Edo_Sgte = Inicio;
			end
	endcase
end

assign EstadoSiguiente = Edo_Sgte[1:0];

endmodule 

module Comparador(
input if_branch,
input [27:0]BIPC,Tag,
output reg HitMiss
);

always @(*)
begin

if( (BIPC==Tag) & if_branch )
HitMiss=1;
else
HitMiss=0;

end
endmodule

