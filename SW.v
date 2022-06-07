
module PE (query, ref, H_lu, H_l, H_u, I_u, D_l, H, I, D);
    input  [1:0]  query;
    input  [1:0]  ref;
    input  signed [7:0]  H_l, H_u, H_lu, I_u, D_l;
    output reg signed [7:0]  H, I, D;
    reg signed [3:0] S;
    
    
    always @(*) begin
        I = (((H_u - 6'sd2) > (I_u - 6'sd1)) ? (H_u - 6'sd2) : (I_u - 6'sd1));
        D = (((H_l - 6'sd2) > (D_l - 6'sd1)) ? (H_l - 6'sd2) : (D_l - 6'sd1));
        S = ((ref == query) ? 2 : -1);
        // $display("hihi %d %d D = %d, S = %d", (H_l - 6'sd2), (D_l - 6'sd1), D, S);
        // $display("H_u + S = %d, S = %d, H_u = %d, ref = %d, query = %d", I, S, H_u, ref, query);
        // $display("conditions, %d %d %d", H_lu + S, D, I);
        if (H_lu + S >= I && H_lu + S >= D && H_lu + S >= 0) begin
            H = H_lu + S;
            // $display("H1 = %d", H);
        end
        else if (I >= H_lu + S && I >= D && I >= 0) begin
            H = I;
            // $display("H2 = %d", H);
        end
        else if (D >= H_lu + S && D >=I && D >= 0) begin
            H = D;
            // $display("H3 = %d", H);
        end
        else begin
            H = 8'd0;
            // $display("H4 = %d", H);
        end
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





reg  signed [7:0]  D_PE_r[0:15];
reg  signed [7:0]  D_PE_w[0:15];
reg  signed [7:0]  I_PE_r[0:15];
reg  signed [7:0]  I_PE_w[0:15];
reg  signed [7:0]  H_PE_r[0:15];
reg  signed [7:0]  H_PE_w[0:15];

reg         [6:0]  index_i[15:0], index_i_nxt[15:0];    // num = 64
reg         [5:0]  index_j[15:0], index_j_nxt[15:0];    // num = 48 
reg         [2:0]  state, state_nxt;
reg         [6:0]  counter_R, counter_R_nxt; // num = 64
reg         [5:0]  counter_Q, counter_Q_nxt; // num = 48
reg         [7:0]  counter_cal, counter_cal_nxt; // num = 16*12 = 192


// input FF
reg                valid_r, valid_w;
reg         [1:0]  data_ref_r, data_ref_w;
reg         [1:0]  data_query_r, data_query_w;
reg         [1:0]  R[64:0];
reg         [1:0]  R_nxt_r, R_nxt_w;
reg         [1:0]  Q[48:0];
reg         [1:0]  Q_nxt_r, Q_nxt_w;


// output FF
reg  signed [WIDTH_SCORE - 1:0]       max_r, max_w;
reg         [WIDTH_POS_REF - 1:0]     pos_ref_r, pos_ref_w;
reg         [WIDTH_POS_QUERY - 1:0]   pos_query_r, pos_query_w; 
reg                                   finish_r, finish_w;

reg [1:0] PE_Q[15:0], PE_R[15:0];
reg [7:0] PE_H_S[15:0], PE_H_V[15:0], PE_H_H[15:0], PE_I_V[15:0], PE_D_H[15:0];
reg signed [7:0] H_out[15:0], H_out_previous[15:0];
reg signed [7:0] I_out[15:0], D_out[15:0], H_last[64:0], I_last[64:0];
// wires
wire [7:0] H[15:0], D[15:0], I[15:0];

assign      finish = finish_r;
assign      max = max_r;
assign      pos_ref = pos_ref_r;
assign      pos_query = pos_query_r;


//------------------------------------------------------------------
// submodule
//------------------------------------------------------------------
    // PE PE1(
    //     .query(), ref, H_lu, H_l, H_u, I_u, D_l, H, I, D
    // );

    always @(*) begin
        case (state)
            IDLE: begin
                if (!reset) 
                    state_nxt = READ;
                else 
                    state_nxt = IDLE;
            end
            READ: begin
                if (counter_R == 64 && counter_Q == 48) begin // The last item is read
                    state_nxt = CAL;
                    // $display("The next state is CAL lalalalalalalalalalala");
                end
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
        index_i_nxt[0] = index_i[0];
        index_j_nxt[0] = index_j[0];
        index_i_nxt[1] = index_i[1];
        index_j_nxt[1] = index_j[1];
        index_i_nxt[2] = index_i[2];
        index_j_nxt[2] = index_j[2];
        index_i_nxt[3] = index_i[3];
        index_j_nxt[3] = index_j[3];

        case (state)
            READ: begin
                if (valid_r) begin
                    if (counter_R < 64) begin
                        counter_R_nxt = counter_R + 1;
                        R_nxt_w = data_ref_r;
                        // $display("counter_R_nxt = %d", counter_R_nxt);
                    end
                    else begin
                        counter_R_nxt = counter_R;
                        R_nxt_w = R_nxt_r;
                    end
                
                    if (counter_Q < 48) begin
                        counter_Q_nxt = counter_Q + 1;
                        Q_nxt_w = data_query_r;
                        // $display("counter_Q = %d", counter_Q);
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
    

    // submodules
    PE PE1(.query(PE_Q[0]), .ref(PE_R[0]), .H_lu(PE_H_S[0]), .H_l(PE_H_H[0]), .H_u(PE_H_V[0]), .I_u(PE_I_V[0]), .D_l(PE_D_H[0]), .H(H[0]), .I(I[0]), .D(D[0]));
    PE PE2(.query(PE_Q[1]), .ref(PE_R[1]), .H_lu(PE_H_S[1]), .H_l(PE_H_H[1]), .H_u(PE_H_V[1]), .I_u(PE_I_V[1]), .D_l(PE_D_H[1]), .H(H[1]), .I(I[1]), .D(D[1]));
    PE PE3(.query(PE_Q[2]), .ref(PE_R[2]), .H_lu(PE_H_S[2]), .H_l(PE_H_H[2]), .H_u(PE_H_V[2]), .I_u(PE_I_V[2]), .D_l(PE_D_H[2]), .H(H[2]), .I(I[2]), .D(D[2]));
    PE PE4(.query(PE_Q[3]), .ref(PE_R[3]), .H_lu(PE_H_S[3]), .H_l(PE_H_H[3]), .H_u(PE_H_V[3]), .I_u(PE_I_V[3]), .D_l(PE_D_H[3]), .H(H[3]), .I(I[3]), .D(D[3]));

    always @(*) begin
        case (state)
            CAL: begin

                // calculate the max
                
                
                // case for PE1
                    if (index_i[0] == 1 && index_j[0] == 1) begin
                        PE_R[0] = R[1];
                        PE_Q[0] = Q[1];
                        PE_H_S[0] = 8'b0;
                        PE_H_V[0] = 8'b0;
                        PE_H_H[0] = 8'b0;
                        PE_I_V[0] = -8'd32;
                        PE_D_H[0] = -8'd32;
                    end
                    else if (index_i[0] > 1 && index_j[0] == 1) begin
                        PE_R[0] = R[index_i[0]];
                        PE_Q[0] = Q[index_j[0]];
                        PE_H_S[0] = 8'b0;
                        PE_H_V[0] = 8'b0;
                        PE_H_H[0] = H_out[0];
                        PE_I_V[0] = -8'd32;
                        PE_D_H[0] = D_out[0];
                    end
                    else if (index_i[0] == 1 && index_j[0] > 1) begin
                        PE_R[0] = R[index_i[0]];
                        PE_Q[0] = Q[index_j[0]];
                        PE_H_S[0] = 8'b0;
                        PE_H_V[0] = H_last[0];
                        PE_H_H[0] = 8'b0;
                        PE_I_V[0] = I_last[0];
                        PE_D_H[0] = -8'd32;
                        // $display("I_last[0] = %d, H_last[0] = %d, index_i[0] = %d, index_j[0] = %d", I_last[0], H_last[0], index_i[0], index_j[0]);
                    end
                    else begin
                        PE_R[0] = R[index_i[0]];
                        PE_Q[0] = Q[index_j[0]];
                        PE_H_S[0] = H_last[index_i[0] - 1];
                        PE_H_V[0] = H_last[index_i[0]];
                        PE_H_H[0] = H_out[0];
                        PE_I_V[0] = I_last[index_i[0]];
                        PE_D_H[0] = D_out[0];
                        // $display("index_i[0] = %d, index_j[0] = %d", index_i[0], index_j[0]);
                        // $display("H_last - 1 = %d, D = %d, H = %d", H_last[index_i[0] - 1], H_last[index_i[0]],  I_last[index_i[0]]);
                    end
                

                // case for PE2
                if (index_i[1] == 1 && index_j[1] == 2 && index_i[0] > 1) begin
                    PE_R[1] = R[index_i[1]];
                    PE_Q[1] = Q[index_j[1]];
                    PE_H_S[1] = 8'b0;
                    PE_H_V[1] = H_out[0];
                    PE_H_H[1] = 8'b0;
                    PE_I_V[1] = I_out[0];
                    PE_D_H[1] = -8'd32;
                    // $display("H_out[0] = %d", H_out[0]);
                end
                else if (index_i[1] > 1) begin 
                    PE_R[1] = R[index_i[1]];
                    PE_Q[1] = Q[index_j[1]];
                    PE_H_S[1] = H_out_previous[0];
                    PE_H_V[1] = H_out[0];
                    PE_H_H[1] = H_out[1];
                    PE_I_V[1] = I_out[0];
                    PE_D_H[1] = D_out[1];
                end
                else if (index_i[1] == 1 && index_j[1] > 2) begin 
                    PE_R[1] = R[index_i[1]];
                    PE_Q[1] = Q[index_j[1]];
                    PE_H_S[1] = 8'b0;
                    PE_H_V[1] = H_out[0];
                    PE_H_H[1] = 8'b0;
                    PE_I_V[1] = I_out[0];
                    PE_D_H[1] = -8'd32;
                end
                else begin
                    PE_R[1] = R[index_i[1]];
                    PE_Q[1] = Q[index_j[1]];
                    PE_H_S[1] = 8'b0;
                    PE_H_V[1] = 8'b0;
                    PE_H_H[1] = 8'b0;
                    PE_I_V[1] = 8'b0;
                    PE_D_H[1] = 8'b0;
                end
                // end of case PE2

                // case for PE3
                if (index_i[2] == 1 && index_j[2] == 3 && index_i[0] > 2) begin
                    PE_R[2] = R[index_i[2]];
                    PE_Q[2] = Q[index_j[2]];
                    PE_H_S[2] = 8'b0;
                    PE_H_V[2] = H_out[1];
                    PE_H_H[2] = 8'b0;
                    PE_I_V[2] = I_out[1];
                    PE_D_H[2] = -8'd32;
                    // $display("H_out[1] = %d", H_out[1]);
                end
                else if(index_i[2] > 1) begin
                    PE_R[2] = R[index_i[2]];
                    PE_Q[2] = Q[index_j[2]];
                    PE_H_S[2] = H_out_previous[1];
                    PE_H_V[2] = H_out[1];
                    PE_H_H[2] = H_out[2];
                    PE_I_V[2] = I_out[1];
                    PE_D_H[2] = D_out[2];
                end
                else if (index_i[2] == 1 && index_j[2] > 3) begin 
                    PE_R[2] = R[index_i[2]];
                    PE_Q[2] = Q[index_j[2]];
                    PE_H_S[2] = 8'b0;
                    PE_H_V[2] = H_out[1];
                    PE_H_H[2] = 8'b0;
                    PE_I_V[2] = I_out[1];
                    PE_D_H[2] = -8'd32;
                end
                else begin
                    PE_R[2] = R[index_i[2]];
                    PE_Q[2] = Q[index_j[2]];
                    PE_H_S[2] = 8'b0;
                    PE_H_V[2] = 8'b0;
                    PE_H_H[2] = 8'b0;
                    PE_I_V[2] = 8'b0;
                    PE_D_H[2] = 8'b0;
                end
                // end of case PE3

                // case for PE4
                if (index_i[3] == 1 && index_j[3] == 4 && index_i[0] > 3) begin
                    PE_R[3] = R[index_i[3]];
                    PE_Q[3] = Q[index_j[3]];
                    PE_H_S[3] = 8'b0;
                    PE_H_V[3] = H_out[2];
                    PE_H_H[3] = 8'b0;
                    PE_I_V[3] = I_out[2];
                    PE_D_H[3] = -8'd32;
                end
                else if(index_i[3] > 1) begin
                    PE_R[3] = R[index_i[3]];
                    PE_Q[3] = Q[index_j[3]];
                    PE_H_S[3] = H_out_previous[2];
                    PE_H_V[3] = H_out[2];
                    PE_H_H[3] = H_out[3];
                    PE_I_V[3] = I_out[2];
                    PE_D_H[3] = D_out[3];
                end
                else if (index_i[3] == 1 && index_j[3] > 4) begin 
                    PE_R[3] = R[index_i[3]];
                    PE_Q[3] = Q[index_j[3]];
                    PE_H_S[3] = 8'b0;
                    PE_H_V[3] = H_out[2];
                    PE_H_H[3] = 8'b0;
                    PE_I_V[3] = I_out[2];
                    PE_D_H[3] = -8'd32;
                end
                else begin
                    PE_R[3] = R[index_i[3]];
                    PE_Q[3] = Q[index_j[3]];
                    PE_H_S[3] = 8'b0;
                    PE_H_V[3] = 8'b0;
                    PE_H_H[3] = 8'b0;
                    PE_I_V[3] = 8'b0;
                    PE_D_H[3] = -8'd32;
                end
                // if ((index_i > 3 && index_i < 64) || index_i < 3) begin
                //     PE4(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // else if (index_i == 2 && index_j > 1) begin 
                //     PE4(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // else begin
                //     PE4(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // // end of case PE4

                // // case for PE4
                // if ((index_i > 3 && index_i < 64) || index_i < 3) begin
                //     PE4(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // else if (index_i == 2 && index_j > 1) begin 
                //     PE4(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // else begin
                //     PE4(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // // end of case PE4

                // // case for PE5
                // if ((index_i > 4 && index_i < 64) || index_i < 4) begin
                //     PE5(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // else if (index_i == 4 && index_j > 1) begin 
                //     PE5(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // else begin
                //     PE5(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // // end of case PE5

                // // case for PE6
                // if ((index_i > 5 && index_i < 64) || index_i < 5) begin
                //     PE6(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // else if (index_i == 5 && index_j > 1) begin 
                //     PE6(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // else begin
                //     PE6(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // // end of case PE6

                // // case for PE6
                // if ((index_i > 5 && index_i < 64) || index_i < 5) begin
                //     PE6(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // else if (index_i == 5 && index_j > 1) begin 
                //     PE6(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // else begin
                //     PE6(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // // end of case PE6

                // // case for PE7
                // if ((index_i > 6 && index_i < 64) || index_i < 6) begin
                //     PE7(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // else if (index_i == 6 && index_j > 1) begin
                //     PE7(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // else begin
                //     PE7(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // // end of case PE7

                // // case for PE8
                // if ((index_i > 7 && index_i < 64) || index_i < 7) begin
                //     PE8(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // else if (index_i == 7 && index_j > 1) begin
                //     PE8(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // else begin
                //     PE8(H_H[0], H_H[1], H_V[0], I[0], D[0], I_w[0], D_w[0], H_H_w[0], H_H_w[1], H_V_w[0]);
                // end
                // // end of case PE8

                // index for PE1
                // $display("index_i[1] = %d, index_f[1] = %d", index_i[1], index_j[1]);
                if (index_i[0] < 7'd64) begin
                    index_i_nxt[0] = index_i[0] + 7'b1;
                    index_j_nxt[0] = index_j[0];
                    if(index_j[0] == 1) begin
                    // $display("index_i[0] = %d, index_j[0] = %d", index_i[0], index_j[0]);
                    // $display("index_i[3] = %d, index_j[3] = %d", index_i[3], index_j[3]);
                    end
                end
                else if(index_i[0] == 7'd64 && index_j[0] < 7'd45) begin
                    index_i_nxt[0] = 7'b1;
                    index_j_nxt[0] = index_j[0] + 7'd4;
                    // $display("index_i[0] = %d, index_j[0] = %d", index_i[0], index_j[0]);
                    // $display("index_i[3] = %d, index_j[3] = %d", index_i[3], index_j[3]);
                end
                else begin
                    index_i_nxt[0] = index_i[0];
                    index_j_nxt[0] = index_j[0];
                end

                // index for PE2
                if (index_i[1] < 7'd64 && index_i[0] > 1) begin
                    index_i_nxt[1] = index_i[1] + 7'b1;
                    index_j_nxt[1] = index_j[1];
                end
                else if(index_i[1] == 7'd64 && index_j[1] < 7'd46) begin
                    index_i_nxt[1] = 7'b1;
                    index_j_nxt[1] = index_j[0] + 7'd4;
                end
                else begin
                    index_i_nxt[1] = index_i[1];
                    index_j_nxt[1] = index_j[1];
                end

                // index for PE3
                if (index_i[2] < 7'd64 && index_i[0] > 2) begin
                    index_i_nxt[2] = index_i[2] + 7'b1;
                    index_j_nxt[2] = index_j[2];
                end
                else if(index_i[2] == 7'd64 && index_j[2] < 7'd47) begin
                    index_i_nxt[2] = 7'b1;
                    index_j_nxt[2] = index_j[2] + 7'd4;
                end
                else begin
                    index_i_nxt[2] = index_i[2];
                    index_j_nxt[2] = index_j[2];
                end

                // index for PE4
                if (index_i[3] < 7'd64 && index_i[0] > 3) begin
                    index_i_nxt[3] = index_i[3] + 7'b1;
                    index_j_nxt[3] = index_j[3];
                end
                else if(index_i[3] == 7'd64 && index_j[3] < 7'd48) begin
                    index_i_nxt[3] = 7'b1;
                    index_j_nxt[3] = index_j[3] + 7'd4;
                end
                else if(index_i[3] == 7'd64 && index_j[3] == 7'd48) begin
                    finish_w = 1'b1;
                end
                else begin
                    index_i_nxt[3] = index_i[3];
                    index_j_nxt[3] = index_j[3];
                end
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
            index_i[0] <= 1;
            index_j[0] <= 1;
            index_i[1] <= 1;
            index_j[1] <= 2;
            index_i[2] <= 1;
            index_j[2] <= 3;
            index_i[3] <= 1;
            index_j[3] <= 4;
            counter_R <= 1;
            counter_Q <= 1;
            counter_cal <= 0;
            state <= 0;
            finish_r <= 0;
            max_r <= 0;
            max_w <= 0;
            pos_ref_r <= 0;
            pos_query_r <= 0;
            valid_r <= 0;
            data_ref_r <= 0;
            data_query_r <= 0;

            // $display("Q: %d, R: %d\n", counter_Q, counter_R);

        end
        else begin
            index_i[0] <= index_i_nxt[0];
            index_j[0] <= index_j_nxt[0];
            index_i[1] <= index_i_nxt[1];
            index_j[1] <= index_j_nxt[1];
            index_i[2] <= index_i_nxt[2];
            index_j[2] <= index_j_nxt[2];
            index_i[3] <= index_i_nxt[3];
            index_j[3] <= index_j_nxt[3];
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
            H_out[0] <= H[0];
            H_out_previous[0] <= H_out[0];
            I_out[0] <= I[0];
            D_out[0] <= D[0];
            H_out[1] <= H[1];
            H_out_previous[1] <= H_out[1];
            I_out[1] <= I[1];
            D_out[1] <= D[1];
            H_out[2] <= H[2];
            H_out_previous[2] <= H_out[2];
            I_out[2] <= I[2];
            D_out[2] <= D[2];
            H_out[3] <= H[3];
            H_out_previous[3] <= H_out[3];
            I_out[3] <= I[3];
            D_out[3] <= D[3];
            H_last[index_i[3]] <= H[3];
            I_last[index_i[3]] <= I[3];
            if (H_out[0] > max_r) begin
                max_w = H_out[0];
                pos_ref_w = index_i[0];
                pos_query_w = index_j[0];
            end
            else if (H_out[1] > max_r) begin
                max_w = H_out[1];
                pos_ref_w = index_i[1];
                pos_query_w = index_j[1];
            end
            else if (H_out[2] > max_r) begin
                max_w = H_out[2];
                pos_ref_w = index_i[2];
                pos_query_w = index_j[2];
            end
            else if (H_out[3] > max_r) begin
                max_w = H_out[3];
                pos_ref_w = index_i[3];
                pos_query_w = index_j[3];
            end
            else begin
                max_w = max_r;
            end
            // $display("H_out[0] = %d, H_out[1] = %d, H_out[2] = %d, H_out[3] = %d, max_r = %d", H_out[0], H_out[1], H_out[2], H_out[3], max_r);
            if (index_i[0] == 3 && index_j[0] == 5)
                $display("I = %d, D = %d, H = %d, index_i = %d, index_j = %d, H_previous = %d", I_out[0], D_out[0],  H_out[0], index_i[0], index_j[0], H_out_previous[0]);
        end
    end
    
endmodule

