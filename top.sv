Top
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 02/04/2025 07:46:08 PM
// Design Name:
// Module Name: top
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module top (
    input  logic        clk_in1_p,
    input  logic        clk_in1_n,
    input  logic        reset,
    input  logic [31:0] trace,
    input  logic        trace_valid,
    output logic [7:0]  neighbours
);

    // Internal signals
    logic        clk_generated;
    logic        locked_signal;

    logic        p_trace_valid;
    logic [31:0] p_trace;

    logic        index_valid;
    logic [12:0] index;


    // Clocking Wizard Instance
    clk_wiz_0 clk_inst (
        .clk_out1(clk_generated), // Output clock
        .reset(reset),            // Reset input
        .locked(locked_signal),   // Locked output
        .clk_in1_p(clk_in1_p),    // Differential clock input +
        .clk_in1_n(clk_in1_n)     // Differential clock input -
    );

    // Mapping Module Instance
    mapping mapping_inst (
        .clk(clk_generated),       // Connect generated clock
        .reset(reset),             // Reset
        .trace(trace),             // 32-bit trace input
        .trace_valid(trace_valid), // Trace valid signal
        .index(index),             // 13-bit index output
        .index_valid(index_valid),  // Index valid signal
        .p_trace(p_trace),
        .p_trace_valid(p_trace_valid)
    );


    neighbour_tracker neighbours_inst(
        .clk(clk_generated),
        .reset(reset),
        .index(index),
        .index_valid(index_valid),
        .trace(p_trace),
        .trace_valid(p_trace_valid),
        .neighbours(neighbours)
    );
endmodule
