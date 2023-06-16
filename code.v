#Design Under Test(DUT): 

module data_acq(adc_data,clk,reset,wr_en,rd_en,data_out); 
input [15:0] adc_data; input clk,reset,wr_en,rd_en; 
output reg[15:0] data_out; reg [15:0] data,fifo_data; reg wr_en,rd_en; 
spi dut1(.adc_data(adc_data),.clk(clk),.reset(reset),.data(data)); 
fifo dut2(.data(data),.wr_en(wr_en),.rd_en(rd_en),.clk(clk),.reset(reset),.fifo_data(fifo_data)); 
ram 
dut3(.fifo_data(fifo_data),.clk(clk),.reset(reset),.wr_en(wr_en),.rd_en(rd_en),.data_out(data_out)); 
endmodule 

#SPI
module spi(adc_data,clk,reset,data); 
input [15:0] adc_data; 
input clk,reset; output reg [15:0] data; reg [4:0] count; reg [15:0] mosi; 
reg cs_l; reg sclk; reg [2:0] state; 
always@(posedge clk) 
if(reset) begin 
count<=5'd16; 
cs_l<=1'b1; 
sclk<=1'b0; 
end else 
begin 
case(state) 
0:begin 
sclk<=1'b0; 
cs_l<=1'b0; 
mosi<=adc_data; 
count<=count-1; 
state<=1; 
end 
1:begin 
sclk<=1'b0; 
if(count>0) 
state<=0; else 
begin 
count<=16; 
state<=0; 
end 
end 
default:state<=0; 
endcase 
end 
assign data=mosi; 
endmodule 

#FIFO
module fifo(data,wr_en,rd_en,clk,reset,fifo_data); 
input [15:0] data; input wr_en,rd_en,reset,clk; 
output reg [15:0] fifo_data; 
reg [15:0] data; reg [4:0] rd_ptr, wr_ptr; reg [5:0]fifo_cnt; reg [15:0] fifo_ram[128]; reg empty,full; 
assign empty = (fifo_cnt==0); 
assign full = (fifo_cnt==32); 
always@(data,wr_en,rd_en) 
 begin 
 if(wr_en==1'b1)                    //write into RAM 
 begin 
fifo_ram[wr_ptr]=data; 
end 
 else if (rd_en==1'b1)              // read from RAM 
 begin 
 fifo_data=fifo_ram[rd_ptr]; 
end 
else 
begin 
fifo_data=fifo_data; end 
end 
always@(wr_en,rd_en,reset) begin: 
pointer 
 if( reset ) 
begin 
wr_ptr = 0; 
rd_ptr = 0; 
end 
 else 
begin 
 wr_ptr <= ((wr_en && !full)||(wr_en && rd_en)) ? wr_ptr+1 : wr_ptr; 
rd_ptr <= ((rd_en && !empty)||(!wr_en && rd_en)) ? rd_ptr+1 : rd_ptr; 
end 
end 
always @( posedge clk ) 
begin: 
counter 
 if( reset ) 
 fifo_cnt <= 0; 
 else 
 begin 
case ({wr_en,rd_en}) 
 2'b00 : fifo_cnt <= fifo_cnt; 
 2'b01 : fifo_cnt <= (fifo_cnt==0) ? 0 : fifo_cnt-1; 
 2'b10 : fifo_cnt <= (fifo_cnt==32) ? 32 : fifo_cnt+1; 
 2'b11 : fifo_cnt <= fifo_cnt; 
default: fifo_cnt <= fifo_cnt; 
endcase 
end 
end 
endmodule 

module ram(fifo_data,clk,reset,wr_en,rd_en,data_out); 
input [15:0] fifo_data; input clk,reset,wr_en,rd_en; 
output reg [15:0] data_out; reg [4:0] wr_ptr_m,rd_ptr_m; reg [15:0] mem[(2**7):0]; 
always@(posedge clk ) 
begin 
if(reset==1'b1) 
 begin 
 for(int unsigned i=0;i<2**8;i++) 
begin 
mem[i]<=0; 
data_out<=0; 
end 
end 
end 
always@(wr_en,rd_en,reset) 
begin: memory 
 if( reset ) 
begin 
wr_ptr_m = 0; 
rd_ptr_m = 0; 
end 
else 
begin 
 wr_ptr_m <= ((wr_en )||(wr_en && rd_en)) ? wr_ptr_m+1 : wr_ptr_m; 
rd_ptr_m<= ((rd_en )||(!wr_en && rd_en)) ? rd_ptr_m+1 : rd_ptr_m; 
end 
end 
 always@(fifo_data,wr_en,rd_en) 
 begin 
 if(wr_en==1'b1)                  //write into RAM 
begin 
 mem[wr_ptr_m]=fifo_data; 
 end 
 else if (rd_en==1'b1)            // read from RAM 
begin 

 data_out=mem[rd_ptr_m]; 
end 
else 
begin 
data_out=data_out; 
end 
end 
endmodule 

#UVM Testbench: 
import uvm_pkg::*; 
`include "uvm_macros.svh" 

// data_interface 
data_if(input logic clk,reset); 
 //---------------------------------------
 //declaring the signals 
 //--------------------------------------- 
logic wr_en; logic rd_en; 
logic [15:0] adc_data; 
logic [15:0] data_out; 
 //---------------------------------------
 //driver clocking block 
 //---------------------------------------
 clocking driver_cb @(posedge clk); 
default input #1 output #1; 
output wr_en; output rd_en; 
output adc_data; input data_out; 
endclocking 

 //monitor clocking block 
 clocking monitor_cb @(posedge clk); 
default input #1 output #1; 
input wr_en; input rd_en; 
input adc_data; input data_out; 
endclocking 
 //---------------------------------------
 //driver modport 
 //---------------------------------------
 modport DRIVER (clocking driver_cb,input clk,reset); 
 //---------------------------------------
 //monitor modport 
 //---------------------------------------
 modport MONITOR (clocking monitor_cb,input clk,reset); endinterface 
//----------------------------------------
// sequence item 
//-----------------------------------------
class data_seq_item extends uvm_sequence_item; 
 //---------------------------------------
 //data and control fields 
 //--------------------------------------- 
bit wr_en; bit rd_en; 
rand bit [15:0] adc_data; bit [15:0] data_out; 

//Utility and Field macros `uvm_object_utils_begin(data_seq_item) 
 `uvm_field_int(adc_data,UVM_ALL_ON) 
 `uvm_object_utils_end 

 //---------------------------------------
 //Constructor 
 //---------------------------------------
 function new(string name = "data_seq_item"); 
 super.new(name); 
endfunction 
 function string convert2string(); 
 return $psprintf("adc_data=%0h ",adc_data); 
endfunction 
constraint data {adc_data<350;} 
endclass 
//==============================================================
// data_sequence - random stimulus 
//==============================================================
class data_sequence extends uvm_sequence#(data_seq_item); 
 `uvm_object_utils(data_sequence) 
 //--------------------------------------- 
 //Constructor 
 //---------------------------------------
 function new(string name = "data_sequence"); 
super.new(name); 
endfunction 
 //---------------------------------------
 // create, randomize and send the item to driver 
 //--------------------------------------- 
task body(); data_seq_item req; 
repeat(100) 
begin 
 req=new(); 
start_item(req); 
assert(req.randomize()); 
finish_item(req); 
end 
endtask 
endclass 
 
//-------------------------------------------------------------------------
// sequencer 
//-------------------------------------------------------------------------
class data_sequencer extends uvm_sequencer#(data_seq_item); 
 `uvm_component_utils(data_sequencer) 
 //---------------------------------------
 //constructor 
 //---------------------------------------
 function new(string name, uvm_component parent); 
super.new(name,parent); endfunction 
function void build_phase(uvm_phase phase); 
super.build_phase(phase); 
endfunction 
endclass 
 
 //-------------------------------------------------------------------------
// driver 
//-------------------------------------------------------------------------
`define DRIV_IF vif.DRIVER.driver_cb class data_driver 
extends uvm_driver #(data_seq_item); 
//---------------------------------------
// Virtual Interface 
virtual data_if vif; 
 `uvm_component_utils(data_driver) 
 //--------------------------------------- 
 // Constructor 
 //--------------------------------------- 
 function new (string name, uvm_component parent); 
super.new(name, parent); 
endfunction : new 
 //--------------------------------------- 
 // build phase 
 //---------------------------------------
 function void build_phase(uvm_phase phase); 
super.build_phase(phase); 
 if(!uvm_config_db#(virtual data_if)::get(this, "", "vif", vif)) 
begin 
`uvm_error("build_phase","driver virtual interface failed"); 
end 
 endfunction: build_phase 
 //--------------------------------------- 
 // run phase 
 //--------------------------------------- 
 virtual task run_phase(uvm_phase phase); 
super.run_phase(phase); 
forever begin 
data_seq_item trans; 
 seq_item_port.get_next_item(trans); 
 uvm_report_info("DATA_DRIVER ", $psprintf("Got Transaction %s",trans.convert2string())); 
 @(posedge vif.DRIVER.clk); 
 `DRIV_IF.wr_en<=1; 
`DRIV_IF.rd_en<=0; 
 `DRIV_IF.adc_data<=trans.adc_data; 
 //---------------------------------------
 //Shifting 
 //---------------------------------------
 @(posedge vif.DRIVER.clk); 

 `DRIV_IF.wr_en<=0; 
`DRIV_IF.rd_en<=0; repeat(5) 
@(posedge vif.DRIVER.clk); 
 `DRIV_IF.rd_en<=1; 
 
 //---------------------------------------
 //Reading 
 //---------------------------------------
 @(posedge vif.DRIVER.clk); 
trans.data_out=`DRIV_IF.data_out; 
seq_item_port.item_done(); 
end 
endtask : run_phase 
 //---------------------------------------
 // drive - transaction level to signal level 
 // drives the value's from seq_item to interface signals 
 //--------------------------------------- endclass 
: data_driver 
 
// monitor 
`define MON_IF vif.MONITOR.monitor_cb class 
data_monitor extends uvm_monitor; 
//---------------------------------------
// Virtual Interface 
virtual data_if vif; 
 //---------------------------------------
 // analysis port, to send the transaction to scoreboard 
 //---------------------------------------

 uvm_analysis_port #(data_seq_item) item_collected_port; 
 //---------------------------------------
 // The following property holds the transaction information currently 
 // begin captured (by the collect_address_phase and data_phase methods). 
//---------------------------------------
 `uvm_component_utils(data_monitor) 

 // new - constructor 
 function new (string name, uvm_component parent); 
super.new(name, parent); 
 item_collected_port = new("item_collected_port", this); 
endfunction 
 //---------------------------------------
 // build_phase - getting the interface handle 
 //---------------------------------------
 function void build_phase(uvm_phase phase); 
super.build_phase(phase); 
 if(!uvm_config_db#(virtual data_if)::get(this, "", "vif", vif)) 
 `uvm_error("build_phase", "No virtual interface specified for this monitor instance") 
endfunction: build_phase 
 //---------------------------------------
 // run_phase - convert the signal level activity to transaction level. 
 // i.e, sample the values on interface signal ans assigns to transaction class fields 
 //---------------------------------------
 virtual task run_phase(uvm_phase phase); super.run_phase(phase); 
 forever begin 
data_seq_item trans; 
trans=new(); 
wait(`MON_IF.wr_en==1); 
 fork 
 trans.adc_data=`MON_IF.adc_data; 
 join 
 wait(`MON_IF.wr_en==0 ); 
repeat(15) begin 
 @(posedge vif.MONITOR.clk); 
 end 
 wait(`MON_IF.rd_en==1 ); 
 fork 
 trans.data_out=`MON_IF.data_out; 
 join 
 item_collected_port.write(trans); 
end 
 endtask : run_phase endclass 
: data_monitor 
class fun_cov extends uvm_subscriber#(data_seq_item); 
`uvm_component_utils(fun_cov) 
data_seq_item trans; 
covergroup 
cg; 
WDATA:coverpoint trans.wr_en { bins wd[16] = {[0:2*16-1]}; } 
RDATA:coverpoint trans.rd_en { bins rd[16] = {[0:2*16-1]}; } 
endgroup 
function new(string name, uvm_component parent); 
super.new(name, parent); cg = new(); 
endfunction 
//new() 
function void build_phase(uvm_phase phase); 

trans = data_seq_item::type_id::create("trans"); endfunction 
function void write(data_seq_item t); this.trans = t; 
cg.sample(); 
endfunction 
endclass 
 
// agent 
class data_agent extends uvm_agent; 

 // component instances 
data_driver driver; 
data_sequencer sequencer; 
data_monitor monitor; virtual 
data_if vif; 
 `uvm_component_utils_begin(data_agent) 
 `uvm_field_object(sequencer, UVM_ALL_ON) 
 `uvm_field_object(driver, UVM_ALL_ON) 
 `uvm_field_object(monitor, UVM_ALL_ON) 
 `uvm_component_utils_end 

 // constructor 
 function new (string name, uvm_component parent); 
super.new(name, parent); 
endfunction : new 

 // build_phase 
virtual function void build_phase(uvm_phase phase); 
 super.build_phase(phase); 

 monitor = data_monitor::type_id::create("monitor", this); 
//creating driver and sequencer only for ACTIVE agent 
driver = data_driver::type_id::create("driver", this); 
sequencer = data_sequencer::type_id::create("sequencer", this); 
uvm_config_db#(virtual data_if)::set(this, "seq", "vif", vif); 
uvm_config_db#(virtual data_if)::set(this, "driv", "vif", vif); 
uvm_config_db#(virtual data_if)::set(this, "mon", "vif", vif); 
if(!uvm_config_db#(virtual data_if)::get(this,"","vif",vif)) 
begin 
 `uvm_error("build_phase","agent virtual interface failed"); 
end 
 endfunction : build_phase 

 // connect_phase - connecting the driver and sequencer port 
 function void connect_phase(uvm_phase phase); 
super.connect_phase(phase); 
 driver.seq_item_port.connect(sequencer.seq_item_export); 
 uvm_report_info("DATA_AGENT", "connect_phase, Connected driver to sequencer"); 
endfunction : connect_phase endclass : data_agent 
 
// scoreboard 
class 
data_scoreboard extends uvm_scoreboard; 
 
 //port to recive packets from monitor 
uvm_analysis_imp#(data_seq_item, data_scoreboard) item_collected_export; 

 `uvm_component_utils(data_scoreboard) data_seq_item 
trans; 

 // new - constructor 
 function new (string name, uvm_component parent); 
super.new(name, parent); 
item_collected_export=new("item_collected_export",this); 
endfunction 
 
 // build_phase - create port and initialize local memory 
 function void build_phase(uvm_phase phase); 
super.build_phase(phase); 
endfunction: 
build_phase 

 // write task - recives the pkt from monitor and pushes into queue 
 function void write(data_seq_item trans); trans.print(); 
`uvm_info("SCOREBOARD",$sformatf("------::RESULT:: ------"),UVM_LOW) 
 `uvm_info("",$sformatf("adc_data:%0h ",trans.adc_data),UVM_LOW) 
`uvm_info("",$sformatf("data_out:%0h ",trans.data_out),UVM_LOW) 
endfunction 
endclass : data_scoreboard 
 
// environment 
class 
data_env extends uvm_env; 

// agent and scoreboard instance 
data_agent agnt; 
data_scoreboard scb; virtual 
data_if vif; 
 `uvm_component_utils(data_env) 

 // constructor 
 function new(string name, uvm_component parent); 
super.new(name, parent); 
endfunction : new 

 // build_phase - crate the components 
 function void build_phase(uvm_phase phase); 
super.build_phase(phase); 
 agnt = data_agent::type_id::create("agnt", this); 
 scb = data_scoreboard::type_id::create("scb", this); 
uvm_config_db#(virtual data_if)::set(this, "agt", "vif", vif); 
uvm_config_db#(virtual data_if)::set(this, "scb", "vif", vif); 
if(! uvm_config_db#(virtual data_if)::get(this, "", "vif", vif)) 
begin 
 `uvm_error("build_phase","Environment virtual interface failed") 
end 
 endfunction : build_phase 

 // connect_phase - connecting monitor and scoreboard port 
 function void connect_phase(uvm_phase phase); super.connect_phase(phase); 
 agnt.monitor.item_collected_port.connect(scb.item_collected_export); 
uvm_report_info("data_ENVIRONMENT", "connect_phase, Connected monitor to scoreboard"); 

 endfunction : connect_phase endclass 
: data_env 

// test 
class data_test extends uvm_test; 
 `uvm_component_utils(data_test) 

 // env instance 
data_env env; virtual data_if vif; 

 // constructor 
 function new(string name ,uvm_component parent); 
super.new(name,parent); endfunction : new 

 // build_phase 
function void build_phase(uvm_phase phase); 
super.build_phase(phase); // Create the env 
 env = data_env::type_id::create("env", this); 
uvm_config_db#(virtual data_if)::set(this, "env", "vif", vif); 
if(! uvm_config_db#(virtual data_if)::get(this, "", "vif", vif)) 
begin 
 `uvm_error("build_phase","Test virtual interface failed") 
end 
 endfunction : build_phase task 
run_phase(uvm_phase phase); 
data_sequence seq; 

seq = data_sequence::type_id::create("seq",this); 
phase.raise_objection(this,"starting main phase"); $display("%t 
Starting sequence spi_seq run_phase",$time); 
seq.start(env.agnt.sequencer); 
 #500ns; 
phase.drop_objection(this,"finished main phase"); 
endtask : run_phase endclass 
 
// testbench.sv 
module testbench_top; 

//clock and reset signal declaration 
bit clk; bit reset; 
 
 //clock generation 
always #5 clk = ~clk; 
 
 //reset Generation 
initial begin reset = 1; 
 #15 reset =0; 
 end 

 //interface instance 
data_if intf(clk,reset); 

 //DUT instance 
data_acq DUT ( .clk(intf.clk), .reset(intf.reset), .wr_en(intf.wr_en), .rd_en(intf.rd_en), .adc_data(intf.adc_data), .data_out(intf.data_out) ); 
 //passing the interface handle to lower heirarchy using set method 
 //and enabling the wave dump 
 
initial begin 
 uvm_config_db#(virtual data_if)::set(uvm_root::get(),"*","vif",intf); 
 $dumpfile("dump.vcd"); 
$dumpvars; 
end 
 
 //calling test 
 
initial 
begin 
run_test("data_test"); 
end 
 
endmodule
