`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 01/24/2025 10:49:10 AM
// Design Name:
// Module Name: Hash
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


module Hash(
    input  logic        clk,
    input  logic        reset,
    input  logic        trace_valid,
    input  logic [31:0] trace,
    output logic        hash_valid,
    output logic [12:0] hash_value
);
    // Intermediate variables
    logic [31:0] a;
    logic [31:0] b;
    logic [31:0] c;
    logic [31:0] temp;

    // Control Flow Register
    logic       compute_hash;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            compute_hash <= 1'b0;
        end else if (trace_valid) begin
            compute_hash <= 1'b1;
        end else begin
            compute_hash <= 1'b0;
        end
    end

    // Rotate function
    function automatic logic [31:0] rot;
        input logic [31:0] value;
        input logic [4:0]  shift;
        rot = (value << shift) | (value >> (32 - shift));
    endfunction

    always_comb begin
        hash_value = 13'b0;
        hash_valid = 1'b0;
        if (compute_hash) begin
            // Initialize values
            a = 32'hdeadbef3;
            b = 32'hdeadbef3;
            c = 32'hdeadbef3;
            a += trace;

            // First step: c ^= b, c -= rot(b, 14)
            c ^= b;
            temp = rot(b, 14);
            c -= temp;

            // Second step: a ^= c, a -= rot(c, 11)
            a ^= c;
            temp = rot(c, 11);
            a -= temp;

            // Third step: b ^= a, b -= rot(a, 25)
            b ^= a;
            temp = rot(a, 25);
            b -= temp;

            // Fourth step: c ^= b, c -= rot(b, 16)
            c ^= b;
            temp = rot(b, 16);
            c -= temp;

            // Fifth step: a ^= c, a -= rot(c, 4)
            a ^= c;
            temp = rot(c, 4);
            a -= temp;

            // Sixth step: b ^= a, b -= rot(a, 14)
            b ^= a;
            temp = rot(a, 14);
            b -= temp;

            // Seventh step: c ^= b, c -= rot(b, 24)
            c ^= b;
            temp = rot(b, 24);
            c -= temp;

            // Final step: Truncate to 13 bits
            hash_value = c[12:0];
            hash_valid = 1'b1;
        end
    end

endmodule
