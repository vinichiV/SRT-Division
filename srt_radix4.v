module radix4_srt_divider (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [31:0] dividend_N,
    input  wire [31:0] divisor_D,

    output reg  [31:0] Q_final,
    output reg  [31:0] R_final,
    output reg         valid
);

    // =================================================================
    // Sign Handling
    // =================================================================
    wire sign_N = dividend_N[31];
    wire sign_D = divisor_D[31];
    wire final_sign = sign_N ^ sign_D;

    wire [31:0] abs_N = sign_N ? (~dividend_N + 1'b1) : dividend_N;
    wire [31:0] abs_D = sign_D ? (~divisor_D + 1'b1) : divisor_D;

    // =================================================================
    // Alignment
    // =================================================================
    reg [4:0] shift_count;
    integer i;
    always @(*) begin
        shift_count = 5'd0;
        for (i = 31; i >= 0; i = i - 1) begin
            if (abs_D[i] == 1'b1 && shift_count == 5'd0) begin
                shift_count = 5'd31 - i;
            end
        end
    end

    wire [63:0] D_aligned = {abs_D, 32'b0} << shift_count;
    wire [63:0] N_aligned = {32'b0, abs_N} << shift_count;

    wire signed [95:0] sD_norm = {32'b0, D_aligned};
    wire signed [95:0] r_0     = {32'b0, N_aligned};

    // =================================================================
    // Thresholds
    // =================================================================
    wire signed [95:0] sD_p18 = sD_norm >>> 3; 
    wire signed [95:0] sD_p38 = (sD_norm >>> 3) + (sD_norm >>> 2);
    wire signed [95:0] sD_n18 = -sD_p18;
    wire signed [95:0] sD_n38 = -sD_p38;

    // =================================================================
    // Registers
    // =================================================================
    reg signed [95:0] r_reg; 
    reg signed [95:0] sD_norm_reg, sD_p18_reg, sD_p38_reg, sD_n18_reg, sD_n38_reg;
    reg [4:0]  shift_count_reg;
    reg        final_sign_reg;
    reg        sign_N_reg; 
    
    reg [31:0] pos_q, neg_q;
    reg [4:0]  iter_count;

    // =================================================================
    // Quotient Selection
    // =================================================================
    reg [1:0] p_bits, n_bits;
    reg signed [95:0] add_term;

    always @(*) begin
        if (r_reg < sD_n38_reg) begin
            p_bits = 2'b00; n_bits = 2'b10; // q_i = -2
            add_term = sD_norm_reg <<< 1;   // + 2D
        end 
        else if (r_reg >= sD_n38_reg && r_reg < sD_n18_reg) begin
            p_bits = 2'b00; n_bits = 2'b01; // q_i = -1
            add_term = sD_norm_reg;         // + D
        end 
        else if (r_reg >= sD_n18_reg && r_reg <= sD_p18_reg) begin
            p_bits = 2'b00; n_bits = 2'b00; // q_i = 0
            add_term = 96'sd0;              // + 0
        end 
        else if (r_reg > sD_p18_reg && r_reg <= sD_p38_reg) begin
            p_bits = 2'b01; n_bits = 2'b00; // q_i = 1
            add_term = -sD_norm_reg;        // - D
        end 
        else begin 
            p_bits = 2'b10; n_bits = 2'b00; // q_i = 2
            add_term = -(sD_norm_reg <<< 1);// - 2D
        end
    end

    // =================================================================
    // FSM
    // =================================================================
    localparam IDLE = 2'b00,
               CALC = 2'b01,
               DONE = 2'b10;
    reg [1:0] state;

    wire [31:0] temp_Q_pos = pos_q - neg_q;
    wire [31:0] temp_Q_neg = pos_q - neg_q - 1'b1;

    wire [6:0]  final_shift   = 7'd32 + {2'b00, shift_count_reg};
    wire [95:0] shifted_R_pos = r_reg >> final_shift;
    wire [95:0] shifted_R_neg = (r_reg + sD_norm_reg) >> final_shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            valid           <= 1'b0;
            Q_final         <= 32'd0;
            R_final         <= 32'd0;
            r_reg           <= 96'sd0;
            pos_q           <= 32'd0;
            neg_q           <= 32'd0;
            iter_count      <= 5'd0;
            
            sD_norm_reg     <= 96'sd0;
            sD_p18_reg      <= 96'sd0;
            sD_p38_reg      <= 96'sd0;
            sD_n18_reg      <= 96'sd0;
            sD_n38_reg      <= 96'sd0;
            shift_count_reg <= 5'd0;
            final_sign_reg  <= 1'b0;
            sign_N_reg      <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    if (start) begin
                        r_reg           <= r_0;
                        sD_norm_reg     <= sD_norm;
                        sD_p18_reg      <= sD_p18;
                        sD_p38_reg      <= sD_p38;
                        sD_n18_reg      <= sD_n18;
                        sD_n38_reg      <= sD_n38;
                        shift_count_reg <= shift_count;
                        final_sign_reg  <= final_sign;
                        sign_N_reg      <= sign_N;
                        
                        pos_q           <= 32'd0;
                        neg_q           <= 32'd0;
                        iter_count      <= 5'd0;
                        state           <= CALC;
                    end
                end

                CALC: begin
                    r_reg <= (r_reg <<< 2) + add_term;
                    pos_q <= (pos_q << 2) | {30'b0, p_bits};
                    neg_q <= (neg_q << 2) | {30'b0, n_bits};

                    if (iter_count == 5'd15) begin
                        state <= DONE;
                    end else begin
                        iter_count <= iter_count + 1'b1;
                    end
                end

                DONE: begin
                    valid <= 1'b1;
                    if (r_reg < 0) begin
                        R_final <= sign_N_reg ? (~shifted_R_neg[31:0] + 1'b1) : shifted_R_neg[31:0];
                        Q_final <= final_sign_reg ? (~temp_Q_neg + 1'b1) : temp_Q_neg;
                    end else begin
                        R_final <= sign_N_reg ? (~shifted_R_pos[31:0] + 1'b1) : shifted_R_pos[31:0];
                        Q_final <= final_sign_reg ? (~temp_Q_pos + 1'b1) : temp_Q_pos;
                    end
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
