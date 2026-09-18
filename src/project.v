`default_nettype none

// =========================================================================
// 1. THE PROCESSING ELEMENT (PE)
// =========================================================================
module systolic_pe_4bit (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              clear_acc,
    input  wire signed [3:0] a_in,
    input  wire signed [3:0] b_in,
    output reg signed [3:0]  a_out,
    output reg signed [3:0]  b_out,
    output reg signed [8:0]  acc_out
);
    wire signed [8:0] a_ext;
    wire signed [8:0] b_ext;
    wire signed [8:0] product;

    assign a_ext  = {{5{a_in[3]}}, a_in};
    assign b_ext  = {{5{b_in[3]}}, b_in};
    assign product = a_ext * b_ext;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out   <= 4'sd0;
            b_out   <= 4'sd0;
            acc_out <= 9'sd0;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            if (clear_acc)
                acc_out <= product;
            else
                acc_out <= acc_out + product;
        end
    end
endmodule

// =========================================================================
// 2. THE 2x2 SYSTOLIC ARRAY
// =========================================================================
module systolic_array_2x2_4bit (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              clear_acc,
    input  wire signed [3:0] a_row0_in,
    input  wire signed [3:0] a_row1_in,
    input  wire signed [3:0] b_col0_in,
    input  wire signed [3:0] b_col1_in,
    output wire signed [8:0] c00,
    output wire signed [8:0] c01,
    output wire signed [8:0] c10,
    output wire signed [8:0] c11
);
    wire signed [3:0] a00_to_a01, a10_to_a11;
    wire signed [3:0] b00_to_b10, b01_to_b11;

    systolic_pe_4bit pe00 (.clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
        .a_in(a_row0_in), .b_in(b_col0_in), .a_out(a00_to_a01), .b_out(b00_to_b10), .acc_out(c00));

    systolic_pe_4bit pe01 (.clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
        .a_in(a00_to_a01), .b_in(b_col1_in), .a_out(), .b_out(b01_to_b11), .acc_out(c01));

    systolic_pe_4bit pe10 (.clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
        .a_in(a_row1_in), .b_in(b00_to_b10), .a_out(a10_to_a11), .b_out(), .acc_out(c10));

    systolic_pe_4bit pe11 (.clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
        .a_in(a10_to_a11), .b_in(b01_to_b11), .a_out(), .b_out(), .acc_out(c11));
endmodule

// =========================================================================
// 3. HARDWARE-SAFE TINY TAPEOUT TOP MODULE
// =========================================================================
module tt_um_crisanto_systolic (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    // 7-State FSM (Safe sequential loading using ONLY ui_in for data)
    localparam STATE_IDLE    = 3'd0;
    localparam STATE_LOAD_A0 = 3'd1;
    localparam STATE_LOAD_A1 = 3'd2;
    localparam STATE_LOAD_B0 = 3'd3;
    localparam STATE_LOAD_B1 = 3'd4;
    localparam STATE_COMPUTE = 3'd5;
    localparam STATE_SEND    = 3'd6;

    reg [2:0] state;
    reg [1:0] compute_count;
    reg [1:0] send_count;

    reg signed [3:0] a00_reg, a01_reg, a10_reg, a11_reg;
    reg signed [3:0] b00_reg, b01_reg, b10_reg, b11_reg;

    reg signed [3:0] a_row0_stream, a_row1_stream;
    reg signed [3:0] b_col0_stream, b_col1_stream;

    wire signed [8:0] c00, c01, c10, c11;
    wire clear_acc = (state == STATE_COMPUTE) && (compute_count == 2'd0);
    reg signed [8:0] selected_result;

    systolic_array_2x2_4bit core_array (
        .clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
        .a_row0_in(a_row0_stream), .a_row1_in(a_row1_stream),
        .b_col0_in(b_col0_stream), .b_col1_in(b_col1_stream),
        .c00(c00), .c01(c01), .c10(c10), .c11(c11)
    );

    // Skewing Logic (Verbatim from Reviewer)
    always @* begin
        a_row0_stream = 4'sd0; a_row1_stream = 4'sd0;
        b_col0_stream = 4'sd0; b_col1_stream = 4'sd0;

        if (state == STATE_COMPUTE) begin
            case (compute_count)
                2'd0: begin
                    a_row0_stream = a00_reg;
                    b_col0_stream = b00_reg;
                end
                2'd1: begin
                    a_row0_stream = a01_reg; a_row1_stream = a10_reg;
                    b_col0_stream = b10_reg; b_col1_stream = b01_reg;
                end
                2'd2: begin
                    a_row1_stream = a11_reg;
                    b_col1_stream = b11_reg;
                end
                default: begin end
            endcase
        end
    end

    // Output Routing Logic
    always @* begin
        case (send_count)
            2'd0: selected_result = c00;
            2'd1: selected_result = c01;
            2'd2: selected_result = c10;
            2'd3: selected_result = c11;
            default: selected_result = 9'sd0;
        endcase
    end

    // Mux outputs
    assign uo_out = (state == STATE_SEND) ? selected_result[7:0] : 8'h00;
    assign uio_out = (state == STATE_SEND) ? {7'b0000000, selected_result[8]} : 8'h00;
    assign uio_oe = (state == STATE_SEND) ? 8'b00000001 : 8'b00000000;
    
    wire _unused = &{uio_in[7:1], 1'b0};

    // Hardware-Safe FSM 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            compute_count <= 2'd0;
            send_count    <= 2'd0;
            a00_reg <= 0; a01_reg <= 0; a10_reg <= 0; a11_reg <= 0;
            b00_reg <= 0; b01_reg <= 0; b10_reg <= 0; b11_reg <= 0;
        end else if (ena) begin
            case (state)
                STATE_IDLE: begin
                    if (uio_in[0]) state <= STATE_LOAD_A0;
                end
                STATE_LOAD_A0: begin
                    a00_reg <= ui_in[3:0];
                    a01_reg <= ui_in[7:4];
                    state <= STATE_LOAD_A1;
                end
                STATE_LOAD_A1: begin
                    a10_reg <= ui_in[3:0];
                    a11_reg <= ui_in[7:4];
                    state <= STATE_LOAD_B0;
                end
                STATE_LOAD_B0: begin
                    b00_reg <= ui_in[3:0];
                    b01_reg <= ui_in[7:4];
                    state <= STATE_LOAD_B1;
                end
                STATE_LOAD_B1: begin
                    b10_reg <= ui_in[3:0];
                    b11_reg <= ui_in[7:4];
                    compute_count <= 2'd0;
                    state <= STATE_COMPUTE;
                end
                STATE_COMPUTE: begin
                    if (compute_count == 2'd3) begin
                        send_count <= 2'd0;
                        state <= STATE_SEND;
                    end else begin
                        compute_count <= compute_count + 2'd1;
                    end
                end
                STATE_SEND: begin
                    if (send_count == 2'd3) begin
                        state <= STATE_IDLE;
                        send_count <= 2'd0;
                    end else begin
                        send_count <= send_count + 2'd1;
                    end
                end
                default: state <= STATE_IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire