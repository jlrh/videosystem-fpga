`timescale 1ns/1ps

module jtaerofgt_sprites #(
    parameter SPRPIPE = 3
)(
    input               rst,
    input               clk,
    input               pxl_cen,
    input       [8:0]   hcnt,
    input       [8:0]   vcnt,
    input               LHBL,
    input               flip,

    output      [11:0]  spr_vaddr,
    input       [15:0]  spr_vq,
    output      [13:0]  sprlook_vaddr,
    input       [15:0]  sprlook_vq,

    output      [19:1]  obj_addr,
    output              obj_cs,
    input       [15:0]  obj_data,
    input               obj_ok,
    output      [18:1]  obj2_addr,
    output              obj2_cs,
    input       [15:0]  obj2_data,
    input               obj2_ok,

    output      [ 9:0]  pxl,
    output              pxl_vld
);

wire        draw, busy, pipe_busy;
wire [15:0] code;
wire [8:0]  xpos;
wire [3:0]  ysub;
wire [5:0]  hzoom;
wire        hflip, hipri_s;
wire [4:0]  color_s;

jtaerofgt_spr_scan u_scan(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .hcnt           ( hcnt          ),
    .vcnt           ( vcnt          ),
    .flip           ( flip          ),
    .spr_vaddr      ( spr_vaddr     ),
    .spr_vq         ( spr_vq        ),
    .sprlook_vaddr  ( sprlook_vaddr ),
    .sprlook_vq     ( sprlook_vq    ),
    .draw           ( draw          ),
    .busy           ( busy          ),
    .pipe_busy      ( pipe_busy     ),
    .code           ( code          ),
    .xpos           ( xpos          ),
    .ysub           ( ysub          ),
    .hzoom          ( hzoom         ),
    .hflip          ( hflip         ),
    .color          ( color_s       ),
    .hipri          ( hipri_s       )
);

wire [8:0] buf_addr;
wire       buf_we;
wire [9:0] buf_din;

jtaerofgt_spr_draw #(.SPRPIPE(SPRPIPE)) u_draw(
    .rst        ( rst         ),
    .clk        ( clk         ),
    .draw       ( draw        ),
    .busy       ( busy        ),
    .pipe_busy  ( pipe_busy   ),

    .flush      ( !LHBL && last_lhbl ),
    .code       ( code        ),
    .xpos       ( xpos        ),
    .ysub       ( ysub        ),
    .hzoom      ( hzoom       ),
    .hflip      ( hflip       ),
    .color      ( color_s     ),
    .hipri      ( hipri_s     ),
    .obj_addr   ( obj_addr    ),
    .obj_cs     ( obj_cs      ),
    .obj_data   ( obj_data    ),
    .obj_ok     ( obj_ok      ),
    .obj2_addr  ( obj2_addr   ),
    .obj2_cs    ( obj2_cs     ),
    .obj2_data  ( obj2_data   ),
    .obj2_ok    ( obj2_ok     ),
    .buf_addr   ( buf_addr    ),
    .buf_we     ( buf_we      ),
    .buf_din    ( buf_din     )
);

reg [511:0] occ;
reg         last_lhbl;
wire        pixel_opaque = buf_din[3:0] != 4'hF;
wire        buf_we_gated = buf_we && !occ[buf_addr];
always @(posedge clk, posedge rst)
    if( rst ) begin
        occ       <= 512'd0;
        last_lhbl <= 1'b0;
    end else begin
        last_lhbl <= LHBL;
        if( !LHBL && last_lhbl )
            occ <= 512'd0;
        else if( buf_we_gated && pixel_opaque )
            occ[buf_addr] <= 1'b1;
    end

jtframe_obj_buffer #(
    .DW          ( 10   ),
    .AW          ( 9    ),
    .ALPHAW      ( 4    ),
    .ALPHA       ( 32'hF ),
    .KEEP_OLD    ( 0    ),

    .FLIP_OFFSET ( 320  )
) u_buffer(
    .clk        ( clk         ),
    .LHBL       ( LHBL        ),
    .flip       ( flip        ),

    .wr_data    ( buf_din     ),
    .wr_addr    ( buf_addr    ),
    .we         ( buf_we_gated),
    .rd_addr    ( hcnt        ),
    .rd         ( pxl_cen     ),
    .rd_data    ( pxl         )
);

assign pxl_vld = pxl[3:0] != 4'hF;

`ifdef SIMULATION
reg [31:0] dbg_cyc2, dbg_t0;
reg        dbg_last_busy;
reg [31:0] dbg_min_act, dbg_max_act, dbg_sum_act, dbg_cnt_act;
reg [31:0] dbg_min_vbl, dbg_max_vbl, dbg_sum_vbl, dbg_cnt_vbl;
reg        dbg_trace_spr2;
initial dbg_trace_spr2 = $test$plusargs("trace_spr2");
wire dbg_frame_tick = pxl_cen && hcnt==9'd0 && vcnt==9'd224;
always @(posedge clk, posedge rst)
    if( rst ) begin
        dbg_cyc2      <= 32'd0;
        dbg_t0        <= 32'd0;
        dbg_last_busy <= 1'b0;
        dbg_min_act <= 32'hFFFF_FFFF; dbg_max_act <= 32'd0; dbg_sum_act <= 32'd0; dbg_cnt_act <= 32'd0;
        dbg_min_vbl <= 32'hFFFF_FFFF; dbg_max_vbl <= 32'd0; dbg_sum_vbl <= 32'd0; dbg_cnt_vbl <= 32'd0;
    end else begin : dbg_blk
        reg [31:0] dur;
        dbg_cyc2      <= dbg_cyc2 + 32'd1;

        dbg_last_busy <= pipe_busy;
        if( draw ) dbg_t0 <= dbg_cyc2;
        if( dbg_last_busy && !pipe_busy ) begin
            dur = dbg_cyc2 - dbg_t0;
            if( vcnt < 9'd224 ) begin
                if( dur < dbg_min_act ) dbg_min_act <= dur;
                if( dur > dbg_max_act ) dbg_max_act <= dur;
                dbg_sum_act <= dbg_sum_act + dur;
                dbg_cnt_act <= dbg_cnt_act + 32'd1;
            end else begin
                if( dur < dbg_min_vbl ) dbg_min_vbl <= dur;
                if( dur > dbg_max_vbl ) dbg_max_vbl <= dur;
                dbg_sum_vbl <= dbg_sum_vbl + dur;
                dbg_cnt_vbl <= dbg_cnt_vbl + 32'd1;
            end
        end
        if( dbg_trace_spr2 && dbg_frame_tick )
            $display("SPRFETCH act min=%0d max=%0d avg=%0d cnt=%0d | vbl min=%0d max=%0d avg=%0d cnt=%0d",
                dbg_min_act, dbg_max_act, dbg_cnt_act>0 ? dbg_sum_act/dbg_cnt_act : 32'd0, dbg_cnt_act,
                dbg_min_vbl, dbg_max_vbl, dbg_cnt_vbl>0 ? dbg_sum_vbl/dbg_cnt_vbl : 32'd0, dbg_cnt_vbl);
    end
`endif

endmodule
