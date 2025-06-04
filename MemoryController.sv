
`timescale 1ns / 1ps

module MemoryController(
    input  logic        clk,          // Clock signal
    input  logic        reset,        // Reset signal
    input  logic [12:0] hash_value,   // Input hash_value (hash table address)
    input  logic        hash_valid,  // Valid signal for input hash_value
    input  logic [31:0] trace,        // Input trace (data to search or store)
    input  logic        trace_valid,  // Valid signal for input trace
    output logic [12:0] output_counter, // Counter value associated with the trace
    output logic        output_valid,  // Indicates if output is valid
    output logic [31:0] output_trace,
    output logic        output_trace_valid
);

    // BRAM interface signals for hash table access
    logic          ena, enb;          // Enable signals for read/write operations
    logic [12:0]   addra, addrb;      // Address lines for BRAM access
    logic [368:0]  dina, doutb;       // Data input/output for BRAM
    logic [40:0]   wea;               // Write enable mask for BRAM


    // Global counter for unique traces
    logic [12:0] global_counter;

    // Temporary registers for storing BRAM search results
    logic        found_in_bram, pipeline_found_in_bram;
    logic [12:0] counter_from_bram, pipeline_counter_from_bram;

    // Trace buffer for temporary storage of traces (FIFO structure)
    logic [44:0] trace_buffer [4:0];  // Stores recent traces temporarily
    logic [2:0]  trace_buffer_length; // Number of stored traces
    logic        found_in_trace_buffer;
    logic [12:0] counter_from_trace_buffer;

    // Bucket hash_value buffer for tracking last-used hash_value in the hash table bucket
    logic [16:0] bucket_index_buffer [4:0];
    logic [2:0]  bucket_buffer_length;
    logic [2:0]  bucket_index, doutb_bucket_index, pipeline_bucket_index;
    logic [2:0]  found_at_position_in_bucket_buffer;
    logic        found_in_bucket_buffer;

    // Control flow signals for different pipeline stages
    logic enable_search_op;
    logic start_reading_bram;
    logic finish_reading_bram;
    logic finish_reading_buffer;


    // Pipeline registers for staged processing
    logic [31:0]  first_pipeline_trace, second_pipeline_trace, third_pipeline_trace, fourth_pipeline_trace;
    logic [12:0]  first_pipeline_hash_value, second_pipeline_hash_value, third_pipeline_hash_value, fourth_pipeline_hash_value;


    // Instantiate the hash table (dual-port BRAM)
    hash_table bram_inst (
        .clka(clk),
        .ena(ena),
        .addra(addra),
        .dina(dina),
        .wea(wea),

        .clkb(clk),
        .enb(enb),
        .addrb(addrb),
        .doutb(doutb)
    );

    // Stage 1: Initiate BRAM Read Operation
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            enb <= 1'b0;
            addrb <= 13'b0;

            enable_search_op <= 1'b0;

            first_pipeline_trace <= 32'b0;
            first_pipeline_hash_value <= 13'b0;
        end else if (trace_valid && hash_valid) begin
            // ENABLE READING
            enb <= 1'b1; // Enable read on Port B
            addrb <= hash_value; // Set read address

            // ENABLE SEARCH OPERATION
            enable_search_op <= 1'b1; // enable comparison  operation, since the bram output is new

            first_pipeline_hash_value <= hash_value;
            first_pipeline_trace <= trace;
        end else begin
            enable_search_op <= 1'b0;
        end
    end


    // Stage 2: Wait for BRAM Output (Pipeline Delay)
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            second_pipeline_trace <= 32'b0;
            second_pipeline_hash_value <= 13'b0;

            start_reading_bram <= 1'b0;
        end else if (enable_search_op) begin

            second_pipeline_trace <= first_pipeline_trace;
            second_pipeline_hash_value <= first_pipeline_hash_value;

            start_reading_bram <= 1'b1;
        end else begin
            start_reading_bram <= 1'b0;
        end
    end

    // Stage 3: Retrieve Data from BRAM
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            third_pipeline_trace <= 32'b0;
            third_pipeline_hash_value <= 13'b0;

            finish_reading_bram <= 1'b0;
        end else if (start_reading_bram) begin
            third_pipeline_trace <= second_pipeline_trace;
            third_pipeline_hash_value <= second_pipeline_hash_value;

            finish_reading_bram <= 1'b1;
        end else begin // INVALID INPUT
            finish_reading_bram <= 1'b0;
        end
    end

    //Stage 3: Search in BRAM
    always_comb begin
        found_in_bram = 1'b0;
        counter_from_bram = 13'b0;
        for (int i = 0; i < 4; i++) begin
            if (doutb[i*45 +: 32] == third_pipeline_trace || doutb[(i+4)*45 +: 32] == third_pipeline_trace) begin
                found_in_bram = 1'b1;
                counter_from_bram = (doutb[i*45 +: 32] == third_pipeline_trace) ? doutb[i*45 + 32 +: 13] : doutb[(i+4)*45 + 32 +: 13];
                break;
            end
        end
        doutb_bucket_index = doutb[8*45 +: 3];
    end

    // Stage 4: Store intermediate Results
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pipeline_found_in_bram <= 1'b0;
            pipeline_counter_from_bram <= 13'b0;

            fourth_pipeline_trace <= 32'b0;
            fourth_pipeline_hash_value <= 13'b0;

            pipeline_bucket_index <= 3'b0;

            finish_reading_buffer <= 1'b0;
        end else if (finish_reading_bram) begin
            pipeline_found_in_bram <= found_in_bram;
            pipeline_counter_from_bram <= counter_from_bram;


            fourth_pipeline_trace <= third_pipeline_trace;
            fourth_pipeline_hash_value <= third_pipeline_hash_value;

            pipeline_bucket_index <= doutb_bucket_index;

            finish_reading_buffer <= 1'b1;
        end else begin // INVALID INPUT
            finish_reading_buffer <= 1'b0;
        end
    end

    // Stage 4: Search in Trace  Buffer
    always_comb begin
        found_in_trace_buffer = 1'b0;
        counter_from_trace_buffer = 13'b0;
        for (int j = 0; j < 5; j++) begin
            if (trace_buffer[j][44:13] == fourth_pipeline_trace) begin
                found_in_trace_buffer = 1'b1;
                counter_from_trace_buffer = trace_buffer[j][12:0];
                break;
            end
        end
    end


    // Stage 4: Search in Bucket hash_value Buffer
    always_comb begin
        found_in_bucket_buffer = 1'b0;
        found_at_position_in_bucket_buffer = 3'b0;
        bucket_index = pipeline_bucket_index;
        for (int j = 0; j < 5; j++) begin
            if (bucket_index_buffer[j][13:1] == fourth_pipeline_hash_value && bucket_index_buffer[j][0]) begin
                bucket_index = bucket_index_buffer[j][16:14]; // Extract last 3 bits
                found_in_bucket_buffer = 1'b1;
                found_at_position_in_bucket_buffer = j;
                break;
            end
        end
    end


    // Stage 5: Output the Result.
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            output_counter <= 13'b0;
            output_valid <= 1'b0;
            output_trace <= 32'b0;
            output_trace_valid <= 1'b0;
        end else if (finish_reading_buffer) begin
            if (!pipeline_found_in_bram && !found_in_trace_buffer) begin
                output_counter <= global_counter;
                output_valid <= 1'b1;
            end else if (pipeline_found_in_bram) begin
                output_counter <= pipeline_counter_from_bram;
                output_valid <= 1'b1;
            end else begin
                output_counter <= counter_from_trace_buffer;
                output_valid <= 1'b1;
            end
            output_trace <= fourth_pipeline_trace;
            output_trace_valid <= 1;
        end else begin
            output_counter <= 13'b0;
            output_valid <= 1'b0;

            output_trace <= 32'b0;
            output_trace_valid <= 0;
        end
    end


    // Stage 5: Update Bucket Buffer if not found
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            bucket_buffer_length <= 3'b0;
            bucket_index_buffer[0] <= 17'b0;
            bucket_index_buffer[1] <= 17'b0;
            bucket_index_buffer[2] <= 17'b0;
            bucket_index_buffer[3] <= 17'b0;
            bucket_index_buffer[4] <= 17'b0;
        end else if (finish_reading_buffer) begin
            if (!pipeline_found_in_bram && !found_in_trace_buffer) begin
                if (found_in_bucket_buffer) begin
                    bucket_index_buffer[found_at_position_in_bucket_buffer] <= {bucket_index + 1, fourth_pipeline_hash_value, 1'b1};
                end else if (bucket_buffer_length < 5) begin
                    bucket_index_buffer[bucket_buffer_length] <= {bucket_index + 1, fourth_pipeline_hash_value, 1'b1};
                    bucket_buffer_length <= bucket_buffer_length + 1;
                end else begin
                    // If list is full, shift entries and add new one (FIFO behavior)
                    bucket_index_buffer[0] <= bucket_index_buffer[1]; // Shift entries
                    bucket_index_buffer[1] <= bucket_index_buffer[2];
                    bucket_index_buffer[2] <= bucket_index_buffer[3];
                    bucket_index_buffer[3] <= bucket_index_buffer[4];
                    bucket_index_buffer[4] <= {bucket_index + 1, fourth_pipeline_hash_value, 1'b1};
                end
            end
        end
    end


    // Stage 5: Update Trace Buffer if not found
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            trace_buffer_length <= 3'b0;
            trace_buffer[0] <= 45'b0;
            trace_buffer[1] <= 45'b0;
            trace_buffer[2] <= 45'b0;
            trace_buffer[3] <= 45'b0;
            trace_buffer[4] <= 45'b0;

        end else if (finish_reading_buffer) begin
            if (!pipeline_found_in_bram && !found_in_trace_buffer) begin
                if (trace_buffer_length < 5) begin
                    // Add new entry if there's space
                    trace_buffer[trace_buffer_length] <= {fourth_pipeline_trace, global_counter};
                    trace_buffer_length <= trace_buffer_length + 1;
                end else begin
                    // If list is full, shift entries and add new one (FIFO behavior)
                    trace_buffer[0] <= trace_buffer[1]; // Shift the second entry to the first position
                    trace_buffer[1] <= trace_buffer[2];
                    trace_buffer[2] <= trace_buffer[3];
                    trace_buffer[3] <= trace_buffer[4];
                    trace_buffer[4] <= {fourth_pipeline_trace, global_counter}; // Add new entry to the second position
                end
            end
        end
    end


    // Stage 5: Insert if not found
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            global_counter <= 13'b0;
            ena <= 1'b0;
            addra <= 13'b0;
            dina <= 369'b0;
            wea <= 41'b0;
        end else if (finish_reading_buffer) begin
            if (!pipeline_found_in_bram && !found_in_trace_buffer) begin
                ena <= 1'b1; // Enable write on Port A
                addra <= fourth_pipeline_hash_value;

                // Reset the values, otherwise it could overwrite other values
                wea  <= 41'b0;
                dina <= 369'b0;
                // trace with it correspoding counter value
                dina[bucket_index*45 +: 45] <= {global_counter, fourth_pipeline_trace};
                wea[bucket_index*5 +: 5] <= 5'b11111;

                dina[8*45 +: 3] <= bucket_index + 1;
                wea[40] <= 1'b1; // enable last 9 bits for bucket hash_value
                global_counter <= global_counter + 1;
            end else begin
                ena <= 1'b0;
            end
        end else begin
            ena <= 1'b0;
        end
    end

endmodule
