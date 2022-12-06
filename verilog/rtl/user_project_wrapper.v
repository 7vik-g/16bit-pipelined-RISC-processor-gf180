// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_project_wrapper
 *
 * This wrapper enumerates all of the pins available to the
 * user for the user project.
 *
 * An example user project is provided in this wrapper.  The
 * example should be removed and replaced with the actual
 * user project.
 *
 *-------------------------------------------------------------
 */

module user_project_wrapper #(
    parameter BITS = 32
) (
`ifdef USE_POWER_PINS
    inout vdda1,	// User area 1 3.3V supply
    inout vdda2,	// User area 2 3.3V supply
    inout vssa1,	// User area 1 analog ground
    inout vssa2,	// User area 2 analog ground
    inout vccd1,	// User area 1 1.8V supply
    inout vccd2,	// User area 2 1.8v supply
    inout vssd1,	// User area 1 digital ground
    inout vssd2,	// User area 2 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // Analog (direct connection to GPIO pad---use with caution)
    // Note that analog I/O is not available on the 7 lowest-numbered
    // GPIO pads, and so the analog_io indexing is offset from the
    // GPIO indexing by 7 (also upper 2 GPIOs do not have analog_io).
    inout [`MPRJ_IO_PADS-10:0] analog_io,

    // Independent clock (on independent integer divider)
    input   user_clock2,

    // User maskable interrupt signals
    output [2:0] user_irq
    );

/* User project is instantiated  here   */


//---------Processor----------------------------------------------------------------------

    wire clk;
    wire reset;
    wire [12:0] uP_instr_mem_addr;
    wire [15:0] uP_instr;
    wire [7:0] uP_data_mem_addr;
    wire [15:0] uP_read_data = data_read_data;
    wire [15:0] uP_write_data;
    wire uP_dataw_en; 
    wire start;
    wire hlt;
    wire Serial_input;
    wire Serial_output;
    
processor uP(
`ifdef USE_POWER_PINS
    .vccd1(vccd1),	// User area 1 1.8V supply
    .vssd1(vssd1),	// User area 1 digital ground
`endif
    .clk(clk), .reset(reset),
    .instr_mem_addr(uP_instr_mem_addr),
    .instr(uP_instr),
    .data_mem_addr(uP_data_mem_addr),
    .read_data(uP_read_data),
    .write_data(uP_write_data),
    .Dataw_en(uP_dataw_en),
    .start(start),
    .hlt(hlt),
    .Serial_input(Serial_input),
    .Serial_output(Serial_output)
    );
    
    
//-----------Data_memory------------------------------------------------------------------
    wire data_mem_sel = 1'b1;
    wire dataw_en;
    wire [7:0] data_mem_addr;
    wire [15:0] data_write_data;
    wire [15:0] data_read_data;
gf180mcu_fd_ip_sram__sram256x8m8wm1 data_memory_LSB(
	.CLK(clk),
	.CEN(data_mem_sel),
	.GWEN(dataw_en),
	.WEN({8{dataw_en}}),
	.A(data_mem_addr),
	.D(data_write_data[7:0]),
	.Q(data_read_data[7:0]),
	.VDD(vccd1),
	.VSS(vssd1)
        );

gf180mcu_fd_ip_sram__sram256x8m8wm1 data_memory_MSB(
	.CLK(clk),
	.CEN(data_mem_sel),
	.GWEN(dataw_en),
	.WEN({8{dataw_en}}),
	.A(data_mem_addr),
	.D(data_write_data[15:8]),
	.Q(data_read_data[15:8]),
	.VDD(vccd1),
	.VSS(vssd1)
        );

//------------Instruction_memory----------------------------------------------------------
    wire instr_mem_sel = 1'b1;
    wire instrw_en;
    wire [12:0] instr_mem_addr;
    wire [12:8] dummy = instr_mem_addr[12:8];
    wire [15:0] instr_write_data;
    wire [15:0] instr;
gf180mcu_fd_ip_sram__sram256x8m8wm1 instr_memory_LSB(
	.CLK(clk),
	.CEN(instr_mem_sel),
	.GWEN(instrw_en),
	.WEN({8{instrw_en}}),
	.A(instr_mem_addr[7:0]),
	.D(instr_write_data[7:0]),
	.Q(instr[7:0]),
	.VDD(vccd1),
	.VSS(vssd1)
        );

gf180mcu_fd_ip_sram__sram256x8m8wm1 instr_memory_MSB(
	.CLK(clk),
	.CEN(instr_mem_sel),
	.GWEN(instrw_en),
	.WEN({8{instrw_en}}),
	.A(instr_mem_addr[7:0]),
	.D(instr_write_data[15:8]),
	.Q(instr[15:8]),
	.VDD(vccd1),
	.VSS(vssd1)
        );


io_interface IO_interface (
`ifdef USE_POWER_PINS
	.vccd1(vccd1),	// User area 1 1.8V power
	.vssd1(vssd1),	// User area 1 digital ground
`endif

    .wb_clk_i(wb_clk_i),
    .wb_rst_i(wb_rst_i),

    // MGMT SoC Wishbone Slave
/*
    .wbs_cyc_i(wbs_cyc_i),
    .wbs_stb_i(wbs_stb_i),
    .wbs_we_i(wbs_we_i),
    .wbs_sel_i(wbs_sel_i),
    .wbs_adr_i(wbs_adr_i),
    .wbs_dat_i(wbs_dat_i),
    .wbs_ack_o(wbs_ack_o),
    .wbs_dat_o(wbs_dat_o),
*/
    // Logic Analyzer

    .la_data_in(la_data_in),
    .la_data_out(la_data_out),
    .la_oenb (la_oenb),

    // IO Pads

    .io_in (io_in),
    .io_out(io_out),
    .io_oeb(io_oeb),
    
    // clk & reset
    .clk(clk),
    .reset(reset),

    // IRQ
    .irq(user_irq),
    
    // processor related
    .uP_instr_mem_addr(uP_instr_mem_addr),
    .uP_instr(uP_instr),
    .uP_data_mem_addr(uP_data_mem_addr),
    .uP_write_data(uP_write_data),
    .uP_dataw_en(uP_dataw_en),
    .start(start),
    .hlt(hlt),
    
    // data memory related
    .dataw_en(dataw_en),
    .data_mem_addr(data_mem_addr),
    .data_write_data(data_write_data),
    .data_read_data(data_read_data),
    
    // instr memory related
    .instrw_en(instrw_en),
    .instr_mem_addr(instr_mem_addr),
    .instr_write_data(instr_write_data),
    .instr(instr)
    );

endmodule	// user_project_wrapper

`default_nettype wire
