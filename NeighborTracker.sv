`timescale 1ns / 1ps

module neighbour_tracker(
    input  logic        clk,          // Clock signal
    input  logic        reset,        // Reset signal
    input  logic [12:0] index,        // Input index (hash table address)
    input  logic        index_valid,  // Valid signal for input index
    input  logic [31:0] trace,        // Trace to write or search
    input  logic        trace_valid,
    output logic [7:0]  neighbours   // Fake output: req for synthesis to not ignore the URAM (URAM Data req for end to end implementation)
    );

     // URAM Memory Instance
    logic           ena, enb;          // Enable signals for read/write operations
    logic [12:0]    addra, addrb;      // Address lines for BRAM access
    logic [2087:0]  dina, doutb;       // Data input/output for BRAM
    logic           wea;

    // Pipeline Flow Stage Signals
    logic enable_search_op, finish_reading;

    // Trace Encoding
    logic [19:0]    page_id;
    logic [2047:0]  trace_encode;
    logic [9:0]     one_hot_index;
    logic           same_page;

    // In Neighbor
    logic [12:0]    in_neighbor;
    logic [19:0]    in_neighbour_page_id;
    logic           in_neighbor_valid;
    logic [2047:0]  in_neighbor_content;


    // Pipeline registers
    logic [31:0]  first_pipeline_trace, second_pipeline_trace;
    logic [12:0]  first_pipeline_index, second_pipeline_index;

    // Buffer
    logic [2061:0] buffer [2:0];
    logic [2:0]    buffer_length;
    logic          found_in_buffer;

    // Page Content
    logic [2047:0] current_content;

    // Fake Counter
    logic [11:0]    counter;

    // Instantiate the URAM
    design_1_wrapper uram_inst (
        .BRAM_PORTA_0_addr(addra),   // Address for Port A
        .BRAM_PORTA_0_clk(clk),       // Clock for Port A
        .BRAM_PORTA_0_din(dina),     // Data input for Port A
        .BRAM_PORTA_0_en(ena),         // Enable for Port A
        .BRAM_PORTA_0_we(wea),       // Write Enable for Port A

        .BRAM_PORTB_0_addr(addrb),   // Address for Port B
        .BRAM_PORTB_0_clk(clk),       // Clock for Port B
        .BRAM_PORTB_0_dout(doutb),   // Data output for Port B
        .BRAM_PORTB_0_en(enb)        // Enable for Port B
    );


    //Stage 1: Initiate Read
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            enable_search_op <= 1'b0;

            first_pipeline_trace <= 32'b0;
            first_pipeline_index <= 13'b0;
            addrb <= 13'b0;
            enb <= 1'b0;
        end else if (trace_valid && index_valid) begin
            // ENABLE SEARCH OPERATION
            addrb <= index;
            enb <= 1'b1;
            enable_search_op <= 1'b1; // enable comparison  operation, since the bram output is new

            first_pipeline_index <= index;
            first_pipeline_trace <= trace;
        end else begin
            // Deactivate reading if the trace is invalid or the previous one is the same with the current one
            enable_search_op <= 1'b0;
        end
    end

    // Stage 2: Store intermediate results
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            finish_reading <= 1'b0;
            second_pipeline_trace <= 32'b0;
            second_pipeline_index <= 13'b0;

        end else if (enable_search_op) begin

            second_pipeline_index <= first_pipeline_index;
            second_pipeline_trace <= first_pipeline_trace;

            finish_reading <= 1'b1;
        end else begin
            finish_reading <= 1'b0;
        end
    end


    //Stage 2: Search Buffer
    always_comb begin
        found_in_buffer = 1'b0;
        current_content = in_neighbor_content;

        for (int i = 0; i < 3; i++) begin
            if(buffer[i][2060:2048] == in_neighbor && buffer[i][2061]) begin
                found_in_buffer = 1'b1;
                current_content = buffer[i][2047:0];
            end
        end
    end

    //Stage 2: Encode the trace
    always_comb begin
        page_id       = 20'b0;
        one_hot_index = 10'b0;
        trace_encode  = 2048'b0;
        same_page     = 1'b0;
        // Extract 20-bit page ID
        page_id = second_pipeline_trace[31:12];

        // Extract 10-bit index (for encoding)
        one_hot_index = second_pipeline_trace[11:2];

        // One-hot encode the 10-bit index
        if (page_id == in_neighbour_page_id) begin
            trace_encode[one_hot_index] = 1'b1; // first page [1023:0]
        end else begin
            trace_encode[1024 + one_hot_index] = 1'b1; // second page [2047:1024]
        end
    end

    // Stage 3: Fake Output
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            neighbours <= 8'b0;
            counter <= 12'b0;
        end else if(finish_reading) begin
            neighbours <= doutb [counter +: 8];
            counter <= (counter + 1) % 2080;
        end else begin
            counter <= 12'b0;
            neighbours <= 8'b0;
        end
    end

    // Stage 3: Update In_Neighbour
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            in_neighbor <= 13'b0;
            in_neighbour_page_id <= 20'b0;
            in_neighbor_valid <= 1'b0;
            in_neighbor_content <= 2048'b0;
        end else if (finish_reading) begin
            in_neighbor <= second_pipeline_index;
            in_neighbour_page_id <= page_id;
            in_neighbor_valid <= 1'b1;

            in_neighbor_content <= doutb[2047:0];

        end // Keep the in_neighbor if the trace was invalid
    end


    // Stage 3: Update Buffer
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            buffer[0] <= 2062'b0;
            buffer[1] <= 2062'b0;
            buffer[2] <= 2062'b0;
            buffer_length <= 3'b0;
        end else begin
            if (finish_reading && in_neighbor_valid) begin
                if(buffer_length < 3) begin
                    buffer[buffer_length][2047:0]<= current_content | trace_encode;
                    buffer[buffer_length][2060:2048] <= in_neighbor;
                    buffer[buffer_length][2061] <= 1'b1;
                    buffer_length <= buffer_length + 1;
                end else begin
                    buffer[0] <= buffer[1];
                    buffer[1] <= buffer[2];

                    buffer[2][2047:0] <= current_content | trace_encode;
                    buffer[2][2060:2048] <= in_neighbor;
                    buffer[2][2061] <= 1'b1;
                end
            end
        end
    end

    // Stage 3: Update URAM
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // Initialize Dina
            wea  <= 1'b0;
            ena  <= 1'b0;
            dina <= 2088'b0;
            addra <= 13'b0;
        end else if (finish_reading && in_neighbor_valid) begin
            wea <= 1'b1;
            ena <= 1'b1;
            addra <= in_neighbor;

            dina[2047:0]    <= current_content | trace_encode;
            dina[2067:2048] <= in_neighbour_page_id;
            dina[2087:2068] <= page_id;

        end else begin
            ena <= 1'b0;
            wea <= 1'b0;
        end
    end
endmodule
