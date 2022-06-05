module PE ()
    input  [1:0]  query;
    input  [1:0]  ref;
    input  [5:0]  H_l, H_u, H_lu, I_u, D_l;
    output [5:0]  H, I, D;
    wire signed [3:0] S;
    I = (H_u - 6'd2) > (I_u - 6'd1) ? (H_u - 6'd2) : (I_u - 6'd1);
    D = (H_l - 6'd2) > (D_l - 6'd1) ? (H_l - 6'd2) : (I_l - 6'd1);
    S = (ref == query) ? 2 : -1;
    if (H_lu + S >= I && H_lu + S >= D && H_lu + S >= 0) begin
        H = H_lu + S;
    end
    else if (I >= H_lu + S && I >= D && I >= 0) begin
        H = I;
    end
    else if (D >= H_lu + S && D >=I && D >= 0) begin
        H = D;
    end
    else begin
        H = 6'd0;
    end

endmodule

module SW #(parameter WIDTH_SCORE = 8, parameter WIDTH_POS_REF = 7, parameter WIDTH_POS_QUERY = 6)
(
    input           clk,
    input           reset,
    input           valid,
    input [1:0]     data_ref,
    input [1:0]     data_query,
    output          finish,
    output [WIDTH_SCORE - 1:0]   max,
    output [WIDTH_POS_REF - 1:0]   pos_ref,
    output [WIDTH_POS_QUERY - 1:0]   pos_query
);

//------------------------------------------------------------------
// parameter
//------------------------------------------------------------------
parameter match = 2;
parameter mismatch = -1;
parameter g_open = 2;
parameter g_extend = 1;
parameter IDLE = 2'd0; 
parameter READ = 2'd1; 
parameter CAL = 2'd2; 
parameter READY = 2'd3; 

integer i, j;

//------------------------------------------------------------------
// reg & wire
//------------------------------------------------------------------
reg  signed [5:0]  D_boundary_r[0:47];   // num = 48
reg  signed [5:0]  I_boundary_r[0:3];    // num = 4
reg  signed [5:0]  H_1_boundary_r[0:4];  // num = 5
reg  signed [5:0]  H_2_boundary_r[0:47]; // num = 48

reg  signed [5:0]  new_D_w[0:3];
reg  signed [5:0]  new_I_w[0:3];
reg  signed [5:0]  new_H_1_w[0:4];
reg  signed [5:0]  new_H_2_w[0:4];




reg  signed [5:0]  D_PE_r[0:15];
reg  signed [5:0]  D_PE_w[0:15];
reg  signed [5:0]  I_PE_r[0:15];
reg  signed [5:0]  I_PE_w[0:15];
reg  signed [5:0]  H_PE_r[0:15];
reg  signed [5:0]  H_PE_w[0:15];

reg         [6:0]  index_i, index_i_nxt;    // num = 64
reg         [5:0]  index_j, index_j_nxt;    // num = 48 
reg         [2:0]  state, state_nxt;
reg         [5:0]  counter_R, counter_R_nxt; // num = 64
reg         [5:0]  counter_Q, counter_Q_nxt; // num = 48
reg         [7:0]  counter_cal, counter_cal_nxt; // num = 16*12 = 192


// input FF
reg                valid_r, valid_w;
reg         [1:0]  data_ref_r, data_ref_w;
reg         [1:0]  data_query_r, data_query_w;
reg         [1:0]  R[63:0];
reg         [1:0]  R_nxt_r, R_nxt_w;
reg         [1:0]  Q[47:0];
reg         [1:0]  Q_nxt_r, Q_nxt_w;


// output FF
reg  signed [WIDTH_SCORE - 1:0]       max_r, max_w;
reg         [WIDTH_POS_REF - 1:0]     pos_ref_r, pos_ref_w;
reg         [WIDTH_POS_QUERY - 1:0]   pos_query_r, pos_query_w; 
reg                                   finish_r, finish_w;

assign      finish = finish_r;
assign      max = max_r;
assign      pos_ref = pos_ref_r;
assign      pos_query = pos_query_r;


//------------------------------------------------------------------
// submodule
//------------------------------------------------------------------

    always @(*) begin
        case (state)
            IDLE: begin
                if (!reset) 
                    state_nxt = READ;
                else 
                    state_nxt = IDLE;
            end
            READ: begin
                if (counter_R == 64 && counter_Q == 48) // The last item is read
                    state_nxt = CAL;
                else
                    state_nxt = READ;
            end
            CAL: begin
                if (counter_cal == 192)
                    state_nxt = READY;
                else 
                    state_nxt = CAL;
            end
            READY: begin
                state_nxt = IDLE;
            end
            default: state_nxt = state; // The next state is default to be the current state

        endcase
    
    end

//------------------------------------------------------------------
// combinational part
//------------------------------------------------------------------

    always @(*) begin
        valid_w = valid;
        data_ref_w = data_ref;
        data_query_w = data_query;

        case (state)
            READ: begin
                if (valid_r) begin
                    if (counter_R < 64) begin
                        counter_R_nxt = counter_R + 1;
                        R_nxt_w = data_ref_r;
                    end
                    else begin
                        counter_R_nxt = counter_R;
                        R_nxt_w = R_nxt_r;
                    end
                
                    if (counter_Q < 48) begin
                        counter_Q_nxt = counter_Q + 1;
                        Q_nxt_w = data_query_r;
                    end
                    else begin
                        counter_Q_nxt = counter_Q;
                        Q_nxt_w = Q_nxt_r;
                    end
                end
                else begin
                    counter_R_nxt = counter_R;
                    counter_Q_nxt = counter_Q;
                    R_nxt_w = R_nxt_r;
                    Q_nxt_w = Q_nxt_r;
                end

            end
            default begin
                counter_R_nxt = counter_R;
                counter_Q_nxt = counter_Q;
                R_nxt_w = R_nxt_r;
                Q_nxt_w = Q_nxt_r;
            end
        endcase
    end
    
    always @(*) begin
        case (state)
            CAL: begin
                // if (index_i == 1 && index_j == 1) begin
                //     PE1(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // else if (index_i == 2 && index_j == 1) begin
                //     PE1(H_H[1], H_H[2], H_V[0], I[1], D[0], I_w[1], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                //     PE2(H_H[0], H_H[1], H_V[0], I[0], D[1], I_w[0], D_w[1], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // else if (index_i == 3 && index_j == 1) begin
                //     PE1(H_H[1], H_H[2], H_V[0], I[2], D[0], I_w[2], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                //     PE2(H_H[0], H_H[1], H_V[0], I[1], D[1], I_w[1], D_w[1], H_H_w[0], H_H_w[1], H_V_w[0]);
                //     PE3(H_H[0], H_H[1], H_V[0], I[0], D[2], I_w[0], D_w[2], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                if (index_i == 1 && index_j == 1) begin
                    
            end
            default: begin
                
            end
        endcase
    end

    always @(*) begin
        case (state)
            READY: finish_w = 1;
            default: finish_w = finish_r;
        endcase
    end

//------------------------------------------------------------------
// sequential part
//------------------------------------------------------------------
    always@(posedge clk or posedge reset) begin
        if(reset) begin
            R_nxt_r <= 0;
            Q_nxt_r <= 0;
            index_i <= 0;
            index_j <= 0;
            counter_R <= 0;
            counter_Q <= 0;
            counter_cal <= 0;
            state <= 0;
            finish_r <= 0;
            max_r <= 0;
            pos_ref_r <= 0;
            pos_query_r <= 0;
            valid_r <= 0;
            data_ref_r <= 0;
            data_query_r <= 0;

            // $display("Q: %d, R: %d\n", counter_Q, counter_R);

        end
        else begin
            index_i <= index_i_nxt;
            index_j <= index_j_nxt;
            state <= state_nxt;
            counter_R <= counter_R_nxt;
            counter_Q <= counter_Q_nxt;
            counter_cal <= counter_cal_nxt;
            R[counter_R] <= R_nxt_w;
            Q[counter_Q] <= Q_nxt_w;
            finish_r <= finish_w;
            max_r <= max_w;
            pos_ref_r <= pos_ref_w;
            pos_query_r <= pos_query_w;
            R_nxt_r <= R_nxt_w;
            Q_nxt_r <= Q_nxt_w;
            valid_r <= valid_w;
            data_query_r <= data_query_w;
            data_ref_r <= data_ref_w;
            D_boundary_r[0] <= new_D_w[0];
            D_boundary_r[1] <= new_D_w[1];
            D_boundary_r[2] <= new_D_w[2];
            D_boundary_r[3] <= new_D_w[3];
            I_boundary_r[0] <= new_I_w[0];
            I_boundary_r[1] <= new_I_w[1];
            I_boundary_r[2] <= new_I_w[2];
            I_boundary_r[3] <= new_I_w[3];
            H_1_boundary_r[0] <= new_H_1_w[0];
            H_1_boundary_r[1] <= new_H_1_w[1];
            H_1_boundary_r[2] <= new_H_1_w[2];
            H_1_boundary_r[3] <= new_H_1_w[3];
            H_1_boundary_r[4] <= new_H_1_w[4];
            H_2_boundary_r[0+index_j*4] <= new_H_2_w[0];
            H_2_boundary_r[1+index_j*4] <= new_H_2_w[1];
            H_2_boundary_r[2+index_j*4] <= new_H_2_w[2];
            H_2_boundary_r[3+index_j*4] <= new_H_2_w[3];
            H_2_boundary_r[4+index_j*4] <= new_H_2_w[4];

        end
    end
    
endmodule

