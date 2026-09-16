`timescale 1ns/1ps

module jtaerofgt_spr_draw #(
    parameter ZW = 6,

    parameter SPRPIPE = 3
)(
    input               rst,
    input               clk,

    input               draw,

    input               flush,
    output              busy,

    output              pipe_busy,

    input       [15:0]  code,
    input       [ 8:0]  xpos,
    input       [ 3:0]  ysub,

    input       [ZW-1:0] hzoom,
    input               hflip,

    input       [ 4:0]  color,
    input               hipri,

    output      [19:1]  obj_addr,
    output reg          obj_cs,
    input       [15:0]  obj_data,
    input               obj_ok,
    output      [18:1]  obj2_addr,
    output reg          obj2_cs,
    input       [15:0]  obj2_data,
    input               obj2_ok,

    output reg  [ 8:0]  buf_addr,
    output              buf_we,
    output      [ 9:0]  buf_din

);

localparam QDEPTH = (SPRPIPE>=3) ? 2 : 1;
localparam QW     = 16+9+4+ZW+1+5+1;

reg  [QW-1:0] q_mem [0:1];
reg  [1:0]    q_v;
reg           q_wp, q_rp;

wire [QW-1:0] q_din  = { code, xpos, ysub, hzoom, hflip, color, hipri };
wire [QW-1:0] q_dout = q_mem[q_rp];
wire [1:0]    q_cnt  = {1'b0,q_v[0]} + {1'b0,q_v[1]};
wire          q_full = q_cnt >= QDEPTH[1:0];
wire          q_vld  = q_v[q_rp];

wire [15:0]   q_code  = q_dout[QW-1            -: 16];
wire [ 8:0]   q_xpos  = q_dout[QW-17           -:  9];
wire [ 3:0]   q_ysub  = q_dout[QW-26           -:  4];
wire [ZW-1:0] q_hzoom = q_dout[QW-30           -: ZW];
wire          q_hflip = q_dout[6];
wire [ 4:0]   q_color = q_dout[5:1];
wire          q_hipri = q_dout[0];

wire        in_obj    = q_code[15:13]==3'b000;
wire        in_obj2   = q_code[15:12]==4'b0100;
wire [12:0] code_obj  = q_code[12:0];
wire [11:0] code_obj2 = q_code[11:0];

wire [19:0] byte_addr_obj  = {code_obj, 7'b0}  + {13'd0, q_ysub, 3'b0};
wire [18:0] byte_addr_obj2 = {code_obj2,7'b0}  + {12'd0, q_ysub, 3'b0};

`ifdef SIMULATION
reg dbg_trace_s32;
initial dbg_trace_s32 = $test$plusargs("trace_spr32");
always @(posedge clk) if (dbg_trace_s32 && q_take && q_xpos==9'd50)
    $display("S32 QTAKE t=%0t q_code=%0d q_xpos=%0d q_ysub=%0d byte_addr_obj=%0d",
              $time, q_code, q_xpos, q_ysub, byte_addr_obj);
`endif

reg  [19:1] f_addr;
reg  [63:0] f_row;
reg         f_busy, f_in_obj, f_in_obj2;
reg  [ 8:0] f_xpos;
reg  [ZW-1:0] f_hzoom;
reg         f_hflip, f_hipri;
reg  [ 4:0] f_color;

reg  [63:0] e_row;
reg         e_busy, e_hflip, e_hipri;

reg  [ZW-1:0] e_hzoom;
reg  [ 4:0] e_color;

assign obj_addr  = f_addr[19:1];
assign obj2_addr = f_addr[18:1];

localparam S_IDLE=0, S_W0=1, S_W1=2, S_W2=3, S_W3=4, S_HOLD=5;
reg [2:0]  fst;

wire       rom_ok   = f_in_obj ? obj_ok : f_in_obj2 ? obj2_ok : 1'b1;
wire [15:0] rom_data = f_in_obj ? obj_data : obj2_data;

wire       row_done  = fst==S_HOLD;

wire       e_last    = e_busy && ({1'b0,dst_col} == dest_w_last);
wire       e_free    = !e_busy || e_last;
wire       handoff   = row_done && e_free && !(flush && SPRPIPE!=0);

wire       q_take    = (fst==S_IDLE) && q_vld && !(flush && SPRPIPE!=0);

assign     busy      = SPRPIPE>=2 ? q_full :
                       SPRPIPE>=1 ? (q_full || f_busy) : (q_full || f_busy || e_busy);
assign     pipe_busy = (q_cnt!=2'd0) || f_busy || e_busy;

reg  [3:0] dst_col;

wire [4:0] dest_w      = {1'b0, e_hzoom[5:1]};
wire [4:0] dest_w_last = dest_w - 5'd1;
wire [7:0] dst_col_num = { dst_col, 4'b0 };
wire [4:0] src_col_div = dst_col_num / { 3'd0, dest_w };
wire [3:0] src_col     = src_col_div > 5'd15 ? 4'd15 : src_col_div[3:0];
wire [3:0] rom_col     = e_hflip ? (4'd15 - src_col) : src_col;

wire [2:0] byte_sel   = rom_col[3:1];
wire       want_hi    = ~rom_col[0];

wire [7:0] cur_byte    = e_row[{byte_sel,3'b000} +: 8];
wire [3:0] cur_nibble  = want_hi ? cur_byte[7:4] : cur_byte[3:0];

assign buf_we  = e_busy;
assign buf_din = { e_hipri, e_color, cur_nibble };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        q_v <= 2'b00; q_wp <= 1'b0; q_rp <= 1'b0;
    end else if( flush && SPRPIPE!=0 ) begin

        q_v <= 2'b00; q_wp <= 1'b0; q_rp <= 1'b0;
    end else begin
        if( q_take ) begin
            q_v[q_rp] <= 1'b0;
            q_rp      <= ~q_rp;
        end
        if( draw && !q_full ) begin
            q_mem[q_wp] <= q_din;
            q_v[q_wp]   <= 1'b1;
            q_wp        <= ~q_wp;
        end
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        fst      <= S_IDLE;
        f_busy   <= 1'b0;
        obj_cs   <= 1'b0;
        obj2_cs  <= 1'b0;
        f_row    <= 64'd0;
        f_in_obj <= 1'b0;
        f_in_obj2<= 1'b0;
    end else if( flush && SPRPIPE!=0 ) begin

        f_busy   <= 1'b0;
        fst      <= S_IDLE;
        obj_cs   <= 1'b0;
        obj2_cs  <= 1'b0;
    end else begin
        case( fst )
            S_IDLE: if( q_vld ) begin
                        f_busy    <= 1'b1;
                        f_addr  <= in_obj  ? byte_addr_obj[19:1]  :
                                   in_obj2 ? byte_addr_obj2[18:1] :
                                             19'd0;
                        obj_cs  <= in_obj;
                        obj2_cs <= in_obj2;
                        fst     <= (in_obj || in_obj2) ? S_W0 : S_HOLD;
                        f_row   <= 64'd0;

                        f_in_obj  <= in_obj;
                        f_in_obj2 <= in_obj2;
                        f_xpos    <= q_xpos;
                        f_hzoom   <= q_hzoom;
                        f_hflip   <= q_hflip;
                        f_color   <= q_color;
                        f_hipri   <= q_hipri;
                    end

            S_W0: if( rom_ok ) begin f_row[15:0]  <= {rom_data[7:0], rom_data[15:8]}; f_addr <= f_addr+19'd1; fst <= S_W1; end
            S_W1: if( rom_ok ) begin f_row[31:16] <= {rom_data[7:0], rom_data[15:8]}; f_addr <= f_addr+19'd1; fst <= S_W2; end
            S_W2: if( rom_ok ) begin f_row[47:32] <= {rom_data[7:0], rom_data[15:8]}; f_addr <= f_addr+19'd1; fst <= S_W3; end
            S_W3: if( rom_ok ) begin f_row[63:48] <= {rom_data[7:0], rom_data[15:8]}; obj_cs <= 1'b0; obj2_cs <= 1'b0; fst <= S_HOLD; end

            S_HOLD: if( handoff ) begin
                        f_busy <= 1'b0;
                        fst    <= S_IDLE;
                    end
            default: fst <= S_IDLE;
        endcase
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        e_busy   <= 1'b0;
        buf_addr <= 9'd0;
        dst_col  <= 4'd0;
        e_row    <= 64'd0;
    end else begin
        if( e_busy ) begin
            if( {1'b0,dst_col} == dest_w_last ) begin
                e_busy <= 1'b0;
            end else begin
                dst_col  <= dst_col + 4'd1;
                buf_addr <= buf_addr + 9'd1;
            end
        end

        if( handoff ) begin
            e_busy   <= 1'b1;
            e_row    <= f_row;
            e_hzoom  <= f_hzoom;
            e_hflip  <= f_hflip;
            e_color  <= f_color;
            e_hipri  <= f_hipri;
            buf_addr <= f_xpos;
            dst_col  <= 4'd0;
        end
    end
end

endmodule
