`timescale 1ns / 1ps


module tb_top;
    // Inputs to DUT
    logic clk;
    logic reset;
    logic [31:0] trace;
    logic trace_valid;

    // Output from DUT
    logic [7:0] neighbours;

    // Instantiate the DUT
    top dut (
        .clk(clk),
        .reset(reset),
        .trace(trace),
        .trace_valid(trace_valid),
        .neighbours(neighbours)
    );

    // Generate differential clock (100 MHz = 10ns period)
    initial begin
        clk = 0;
        forever #2 clk = ~clk;
    end

    // Reset generation: Assert reset for the first 20 time units
    initial begin
        reset = 1;
        #20;
        reset = 0;
    end

    // File reading variables
    integer trace_file, trace_file_no_duplicate, neighbors_tracker_dump_file, mapper_tracker_dump_file;
    integer r;
    reg [31:0] trace_val;


    // Apply trace inputs on each clock cycle
    initial begin
        // Open the preprocessed trace file
        trace_file = $fopen("/trace_values.txt", "r");
        if (trace_file == 0) begin
            $display("ERROR: Unable to open trace_values.txt");
            $finish;
        end

        trace_file_no_duplicate = $fopen("/trace_values_no_duplicates.txt", "r");
        if (trace_file_no_duplicate == 0) begin
            $display("ERROR: Unable to open trace_file_no_duplicate.txt");
            $finish;
        end

        neighbors_tracker_dump_file = $fopen("/neighbors_tracker_dump_file.txt", "w");
        if (neighbors_tracker_dump_file == 0) begin
            $display("ERROR: Unable to open neighbors_tracker_dump_file.txt");
            $finish;
        end

        mapper_tracker_dump_file = $fopen("/mapper_tracker_dump_file.txt", "w");
        if (mapper_tracker_dump_file == 0) begin
            $display("ERROR: Unable to open mapper_tracker_dump_file.txt");
            $finish;
        end

        // Wait until reset is deasserted
        @(negedge reset);

        // Main stimulus loop: read one trace per clock cycle
        while (!$feof(trace_file)) begin
            @(posedge clk);
            // Read the next 32-bit hex value from the file.
            r = $fscanf(trace_file, "%h\n", trace_val);
            // Drive the trace value into the DUT
            trace       = trace_val;
            trace_valid = 1'b1;
        end

        @(posedge clk);
        trace_valid = 1'b0;

        repeat (20)@(posedge clk);

        // Second while loop: read the same file again
        while (!$feof(trace_file_no_duplicate)) begin
            @(posedge clk);
            // Read the next 32-bit hex value from the file.
            r = $fscanf(trace_file_no_duplicate, "%h\n", trace_val);
            // Drive the trace value into the DUT
            trace       = trace_val;
            trace_valid = 1'b1;

            if (dut.mapping_inst.index_valid) begin
                $fdisplay(mapper_tracker_dump_file, "Index: %d, Write Enable: 0", dut.mapping_inst.index);
            end

            if (dut.neighbours_inst.finish_reading) begin
                $fdisplay(neighbors_tracker_dump_file, "In Neighbor content = %h", dut.neighbours_inst.doutb);
            end
        end

        @(posedge clk);
        trace_valid = 1'b0;

        while (dut.neighbours_inst.finish_reading) begin
            if (dut.mapping_inst.index_valid) begin
                $fdisplay(mapper_tracker_dump_file, "Index: %d, Write Enable: 0", dut.mapping_inst.index);
            end
            $fdisplay(neighbors_tracker_dump_file, "In Neighbor content = %h", dut.neighbours_inst.doutb);
            @(posedge clk);
        end


        $fclose(neighbors_tracker_dump_file);
        $fclose(mapper_tracker_dump_file);
        $fclose(trace_file_no_duplicate);
        $fclose(trace_file);
        $finish;


    end

endmodule
