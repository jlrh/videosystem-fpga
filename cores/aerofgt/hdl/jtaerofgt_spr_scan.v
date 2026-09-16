`timescale 1ns/1ps

module jtaerofgt_spr_scan(
    input               rst,
    input               clk,

    input       [8:0]   hcnt,
    input       [8:0]   vcnt,
    input               flip,

    output reg  [11:0]  spr_vaddr,
    input       [15:0]  spr_vq,

    output reg  [13:0]  sprlook_vaddr,
    input       [15:0]  sprlook_vq,

    output reg          draw,
    input                busy,
    input                pipe_busy,

    output reg  [15:0]  code,
    output reg  [ 8:0]  xpos,
    output reg  [ 3:0]  ysub,
    output reg  [ 5:0]  hzoom,
    output reg          hflip,
    output reg  [ 4:0]  color,
    output reg          hipri
);

localparam VTOTAL = 256;

localparam VVIS = 224;
localparam signed [9:0] VVIS_M1 = VVIS - 1;

wire [8:0] vcnt_next  = (vcnt == VTOTAL-1) ? 9'd0 : vcnt + 9'd1;

wire       scan_start = hcnt == 9'd340;

wire [8:0] vcnt_next2 = (vcnt_next == VTOTAL-1) ? 9'd0 : vcnt_next + 9'd1;

localparam
    S_IDLE         = 0,
    S_FINDEND_SET  = 1, S_FINDEND_HOLD = 2, S_FINDEND_READ = 3,
    S_LIST_SET     = 4, S_LIST_HOLD    = 5, S_LIST_READ    = 6,
    S_ATTR_SET     = 7, S_ATTR_HOLD    = 8, S_ATTR_READ    = 9,
    S_CULL         = 10,
    S_TILE_SET     = 11, S_TILE_HOLD   = 12, S_TILE_READ    = 13,
    S_DRAW         = 14, S_DRAW_WAIT   = 15,
    S_TILE_NEXT    = 16,
    S_DY_NEXT      = 17,
    S_LIST_NEXT    = 18,
    S_PRE_HOLD     = 19, S_PRE_READ    = 20;

reg [4:0]  fst;
reg [8:0]  line_target;
reg [12:0] end_idx, idx;
reg [11:0] attr_base;

reg [1:0]  attr_i;
reg [15:0] attr0, attr1, attr2, attr3;
reg        dy_sel;
reg [15:0] code_next;
reg        pre_pending;

wire [8:0] oy         = attr0[8:0];
wire [2:0] ysize      = attr0[11:9];
wire [3:0] zoomy_raw  = attr0[15:12];
wire [8:0] ox         = attr1[8:0];
wire [2:0] xsize      = attr1[11:9];
wire [3:0] zoomx_raw  = attr1[15:12];

wire       flipx      = attr2[14];

wire       flipy      = attr2[15];
wire [5:0] color6     = attr2[13:8];
wire [16:0] map_start = { attr2[0], attr3 };

wire [5:0] zoomy = 6'd32 - {2'd0, zoomy_raw};
wire [5:0] zoomx = 6'd32 - {2'd0, zoomx_raw};
wire [4:0] dest_h = zoomy[5:1];
wire [4:0] dest_w = zoomx[5:1];
wire [7:0] height  = ({5'd0,ysize} + 8'd1) * {3'd0,dest_h};

wire signed [9:0] height_s = {2'b00, height};
wire signed [9:0] base_y = dy_sel ? ({1'b0,oy} - 10'sd512) : {1'b0, oy};

wire signed [9:0] line_s = flip ? (VVIS_M1 - {1'b0,line_target}) : {1'b0, line_target};
wire overlap = (line_s >= base_y) && (line_s < base_y + height_s);

wire [7:0] diff        = line_s - base_y;

reg [9:0] dest_h_recip;
always @(*) case(dest_h)
    5'd8:    dest_h_recip = 10'd512;
    5'd9:    dest_h_recip = 10'd456;
    5'd10:   dest_h_recip = 10'd410;
    5'd11:   dest_h_recip = 10'd373;
    5'd12:   dest_h_recip = 10'd342;
    5'd13:   dest_h_recip = 10'd316;
    5'd14:   dest_h_recip = 10'd293;
    5'd15:   dest_h_recip = 10'd274;
    default: dest_h_recip = 10'd256;
endcase

wire [17:0] ycnt_mul     = diff * dest_h_recip;
wire [3:0]  ycnt         = ycnt_mul[15:12];
wire [7:0] dst_row_full = diff - ycnt * {3'd0,dest_h};
wire [8:0] src_row_num  = {dst_row_full[4:0], 4'b0};
wire [17:0] src_row_mul  = src_row_num * dest_h_recip;
wire [3:0] src_row_div  = src_row_mul[15:12];
wire [3:0] src_row      = src_row_div > 4'd15 ? 4'd15 : src_row_div;
wire [3:0] ysub_w       = src_row ^ {4{flipy}};

wire [3:0] row_visit = flipy ? ({1'b0,ysize} - ycnt) : ycnt;
wire [16:0] map_ptr_base = map_start + row_visit * ({5'd0,xsize} + 5'd1);

reg scan_start_d;
always @(posedge clk, posedge rst) if (rst) scan_start_d <= 1'b0; else scan_start_d <= scan_start;
wire scan_start_pulse = scan_start && !scan_start_d;

wire       lhbl_local   = hcnt < 9'd320;
reg        lhbl_local_d;
always @(posedge clk, posedge rst) if (rst) lhbl_local_d <= 1'b0; else lhbl_local_d <= lhbl_local;
wire       buf_swap_now = !lhbl_local && lhbl_local_d;

reg pending_abort;
wire abort_now = pending_abort && !pipe_busy;

wire [8:0] w0_oy        = spr_vq[8:0];
wire [2:0] w0_ysize     = spr_vq[11:9];
wire [3:0] w0_zoomy_raw = spr_vq[15:12];
wire [5:0] w0_zoomy     = 6'd32 - {2'd0, w0_zoomy_raw};
wire [4:0] w0_dest_h    = w0_zoomy[5:1];
wire [7:0] w0_height    = ({5'd0,w0_ysize} + 8'd1) * {3'd0,w0_dest_h};

wire signed [9:0] w0_height_s = {2'b00, w0_height};
wire signed [9:0] w0_base_y0 = {1'b0, w0_oy};
wire signed [9:0] w0_base_y1 = {1'b0, w0_oy} - 10'sd512;
wire w0_overlap0 = (line_s >= w0_base_y0) && (line_s < w0_base_y0 + w0_height_s);
wire w0_overlap1 = (line_s >= w0_base_y1) && (line_s < w0_base_y1 + w0_height_s);
wire w0_any_overlap = w0_overlap0 | w0_overlap1;

reg [2:0] xcnt;
wire [3:0] col_visit = flipx ? ({1'b0,xsize} - {1'b0,xcnt}) : {1'b0,xcnt};
wire [16:0] map_ptr   = map_ptr_base + {13'd0,col_visit};
wire [9:0]  xoffs_wide = {1'b0,ox} + {3'd0,xcnt} * {5'd0,dest_w};

wire [3:0] col_visit_next = flipx ? ({1'b0,xsize} - {1'b0,xcnt+3'd1}) : {1'b0,xcnt+3'd1};
wire [16:0] map_ptr_next  = map_ptr_base + {13'd0,col_visit_next};

`ifdef SIMULATION

reg dbg_trace_spr;

initial dbg_trace_spr = $test$plusargs("trace_spr") && !$test$plusargs("trace_spr2");
reg [31:0] dbg_cyc;
always @(posedge clk, posedge rst)
    if (rst) dbg_cyc <= 32'd0;
    else if ((fst == S_IDLE && scan_start) || abort_now) begin

        if (dbg_trace_spr) $display("SCANPASS vcnt=%0d new_line=%0d cycles_prev_pass=%0d abort=%0b", vcnt, vcnt_next, dbg_cyc, abort_now);
        dbg_cyc <= 32'd0;
    end else dbg_cyc <= dbg_cyc + 32'd1;

reg [31:0] dbg_work;
reg        dbg_working;
always @(posedge clk, posedge rst)
    if (rst) begin dbg_work <= 32'd0; dbg_working <= 1'b0; end
    else if ((fst == S_IDLE && scan_start) || abort_now) begin
        dbg_work    <= 32'd0;
        dbg_working <= 1'b1;
    end else if (dbg_working) begin
        if (fst == S_LIST_NEXT && idx == 13'd0) begin
            if (dbg_trace_spr) $display("WORKDUR vcnt=%0d cycles_active=%0d", vcnt, dbg_work + 32'd1);
            dbg_working <= 1'b0;
        end else dbg_work <= dbg_work + 32'd1;
    end

always @(posedge clk) if (dbg_trace_spr && !rst && fst == S_CULL && overlap && ox == 9'd111 && oy == 9'd30)
    $display("SPR6 CULL line=%0d dy_sel=%0b diff=%0d ycnt=%0d dst_row_full=%0d src_row=%0d row_visit=%0d map_ptr_base=%0d xsize=%0d ysize=%0d zoomx=%0d zoomy=%0d flipx=%0b flipy=%0b color6=%0d map_start=%0d",
              line_target, dy_sel, diff, ycnt, dst_row_full, src_row, row_visit, map_ptr_base,
              xsize, ysize, zoomx, zoomy, flipx, flipy, color6, map_start);
always @(posedge clk) if (dbg_trace_spr && !rst && fst == S_TILE_READ && ox == 9'd111 && oy == 9'd30)
    $display("SPR6 TILE line=%0d dy_sel=%0b xcnt=%0d col_visit=%0d map_ptr=%0d code=%0d xoffs_wide=%0d ysub=%0d",
              line_target, dy_sel, xcnt, col_visit, map_ptr, sprlook_vq, xoffs_wide, ysub_w);

reg dbg_trace_px;
initial dbg_trace_px = $test$plusargs("trace_px");
localparam DBGLINE = 9'd0, DBGX0 = 9'd0, DBGX1 = 9'd40;
always @(posedge clk) if (dbg_trace_px && !rst && fst == S_TILE_READ && line_target == DBGLINE &&
                            xoffs_wide[8:0] >= DBGX0 && xoffs_wide[8:0] <= DBGX1)
    $display("PXHIT line=%0d dy_sel=%0b ox=%0d oy=%0d xsize=%0d ysize=%0d flipx=%0b flipy=%0b xcnt=%0d map_ptr=%0d code=%0d xoffs_wide=%0d ysub=%0d",
              line_target, dy_sel, ox, oy, xsize, ysize, flipx, flipy, xcnt, map_ptr, sprlook_vq, xoffs_wide, ysub_w);

always @(posedge clk) if (dbg_trace_spr && !rst && fst == S_TILE_READ && ox == 9'd497 && oy == 9'd0)
    $display("WRAPX line=%0d dy_sel=%0b xcnt=%0d map_ptr=%0d code=%0d xoffs_wide_full=%0d xpos=%0d ysub=%0d",
              line_target, dy_sel, xcnt, map_ptr, sprlook_vq, xoffs_wide, xoffs_wide[8:0], ysub_w);

always @(posedge clk) if (dbg_trace_spr && !rst && fst == S_CULL && overlap && ox == 9'd132 && oy == 9'd484)
    $display("YWRAP CULL line=%0d dy_sel=%0b base_y=%0d diff=%0d ycnt=%0d dst_row_full=%0d src_row=%0d ysub=%0d height=%0d",
              line_target, dy_sel, base_y, diff, ycnt, dst_row_full, src_row, ysub_w, height);
always @(posedge clk) if (dbg_trace_spr && !rst && fst == S_TILE_READ && ox == 9'd132 && oy == 9'd484)
    $display("YWRAP TILE line=%0d dy_sel=%0b xcnt=%0d col_visit=%0d map_ptr=%0d code=%0d xoffs_wide=%0d ysub=%0d hcnt_now=%0d vcnt_now=%0d",
              line_target, dy_sel, xcnt, col_visit, map_ptr, sprlook_vq, xoffs_wide, ysub_w, hcnt, vcnt);

always @(posedge clk) if (dbg_trace_spr && !rst && fst == S_CULL && overlap && ox == 9'd50 && oy == 9'd482 && line_target==9'd0)
    $display("S32 CULL line=%0d dy_sel=%0b base_y=%0d diff=%0d ycnt=%0d dst_row_full=%0d src_row=%0d ysub=%0d height=%0d",
              line_target, dy_sel, base_y, diff, ycnt, dst_row_full, src_row, ysub_w, height);
always @(posedge clk) if (dbg_trace_spr && !rst && fst == S_TILE_READ && ox == 9'd50 && oy == 9'd482 && line_target==9'd0)
    $display("S32 TILE line=%0d dy_sel=%0b xcnt=%0d col_visit=%0d map_ptr=%0d code=%0d xoffs_wide=%0d ysub=%0d hcnt_now=%0d vcnt_now=%0d",
              line_target, dy_sel, xcnt, col_visit, map_ptr, sprlook_vq, xoffs_wide, ysub_w, hcnt, vcnt);

always @(posedge clk) if (dbg_trace_spr && !rst && fst == S_CULL && overlap && ox == 9'd165 && oy == 9'd21)
    $display("S36 CULL line=%0d dy_sel=%0b base_y=%0d diff=%0d ycnt=%0d dst_row_full=%0d src_row=%0d ysub=%0d height=%0d row_visit=%0d map_ptr_base=%0d",
              line_target, dy_sel, base_y, diff, ycnt, dst_row_full, src_row, ysub_w, height, row_visit, map_ptr_base);
always @(posedge clk) if (dbg_trace_spr && !rst && fst == S_TILE_READ && ox == 9'd165 && oy == 9'd21)
    $display("S36 TILE line=%0d dy_sel=%0b xcnt=%0d col_visit=%0d map_ptr=%0d code=%0d xoffs_wide=%0d ysub=%0d",
              line_target, dy_sel, xcnt, col_visit, map_ptr, sprlook_vq, xoffs_wide, ysub_w);
always @(posedge clk) if (dbg_trace_spr && !rst && draw && (ox == 9'd165 && oy == 9'd21))
    $display("S36 DRAW line=%0d idx=%0d", line_target, idx);
always @(posedge clk) if (dbg_trace_spr && !rst && draw && (ox == 9'd149 && oy == 9'd18))
    $display("S2930 DRAW line=%0d idx=%0d flipx=%0b", line_target, idx, flipx);
`endif

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        fst           <= S_IDLE;
        draw          <= 1'b0;
        spr_vaddr     <= 12'd0;
        sprlook_vaddr <= 14'd0;
        idx           <= 13'd0;
        end_idx       <= 13'd0;
        attr_i        <= 2'd0;
        dy_sel        <= 1'b0;
        xcnt          <= 3'd0;
        pending_abort <= 1'b0;
        pre_pending   <= 1'b0;
    end else begin
        draw <= 1'b0;

        if( (scan_start_pulse || buf_swap_now) && fst != S_IDLE ) pending_abort <= 1'b1;

        if( abort_now ) begin

            line_target   <= vcnt_next2;
            spr_vaddr     <= 12'd0;
            fst           <= S_FINDEND_SET;
            attr_i        <= 2'd0;
            dy_sel        <= 1'b0;
            xcnt          <= 3'd0;
            pending_abort <= 1'b0;
        end else if( pending_abort ) begin

        end else
        case( fst )
            S_IDLE: if( scan_start ) begin
                        line_target <= vcnt_next2;
                        spr_vaddr   <= 12'd0;
                        fst         <= S_FINDEND_SET;
                    end

            S_FINDEND_SET: begin spr_vaddr <= spr_vaddr; fst <= S_FINDEND_READ; end
            S_FINDEND_READ: begin
                        if( spr_vq[14] || spr_vaddr == 12'hfff ) begin
                            end_idx <= {1'b0, spr_vaddr};
                            idx     <= {1'b0, spr_vaddr} - 13'd1;
                            fst     <= (spr_vaddr == 12'd0) ? S_IDLE : S_LIST_SET;
                        end else begin
                            spr_vaddr <= spr_vaddr + 12'd1;
                            fst       <= S_FINDEND_SET;
                        end
                    end

            S_LIST_SET:  begin spr_vaddr <= idx[11:0]; fst <= S_LIST_HOLD; end
            S_LIST_HOLD: begin                          fst <= S_LIST_READ; end
            S_LIST_READ: begin
                        if( spr_vq[15] ) fst <= S_LIST_NEXT;
                        else begin
                            attr_base <= {spr_vq[9:0], 2'b00};
                            spr_vaddr <= {spr_vq[9:0], 2'b00};
                            attr_i    <= 2'd0;
                            dy_sel    <= 1'b0;
                            fst       <= S_ATTR_HOLD;
                        end
                    end

            S_ATTR_SET:  begin spr_vaddr <= attr_base + {10'd0,attr_i}; fst <= S_ATTR_HOLD; end
            S_ATTR_HOLD: begin                                          fst <= S_ATTR_READ; end
            S_ATTR_READ: begin
                        case( attr_i )
                            2'd0: attr0 <= spr_vq;
                            2'd1: attr1 <= spr_vq;
                            2'd2: attr2 <= spr_vq;
                            2'd3: attr3 <= spr_vq;
                        endcase
                        if( attr_i == 2'd0 && !w0_any_overlap ) begin

                            dy_sel <= 1'b0;
                            fst    <= S_LIST_NEXT;
                        end
                        else if( attr_i == 2'd3 ) fst <= S_CULL;
                        else begin attr_i <= attr_i + 2'd1; fst <= S_ATTR_SET; end
                    end
            S_CULL: begin

                        if( overlap ) begin
                            xcnt <= 3'd0;
                            fst  <= S_TILE_SET;
                        end else fst <= S_DY_NEXT;
                    end

            S_TILE_SET:  begin sprlook_vaddr <= map_ptr[13:0]; fst <= S_TILE_HOLD; end
            S_TILE_HOLD: begin                                  fst <= S_TILE_READ; end
            S_TILE_READ: begin
                        code  <= sprlook_vq;
                        xpos  <= xoffs_wide[8:0];
                        ysub  <= ysub_w;
                        hzoom <= zoomx;
                        hflip <= flipx;
                        color <= color6[4:0];
                        hipri <= color6[5];
                        draw  <= 1'b1;
                        fst   <= S_DRAW;
                    end

            S_DRAW: begin

                        if( xcnt == {2'd0,xsize} ) begin
                            pre_pending <= 1'b0;
                            fst         <= S_DRAW_WAIT;
                        end else begin
                            xcnt          <= xcnt + 3'd1;
                            sprlook_vaddr <= map_ptr_next[13:0];
                            pre_pending   <= 1'b1;
                            fst           <= S_PRE_HOLD;
                        end
                    end

            S_PRE_HOLD: fst <= S_PRE_READ;
            S_PRE_READ: begin code_next <= sprlook_vq; fst <= S_DRAW_WAIT; end
            S_DRAW_WAIT: if( !busy ) fst <= S_TILE_NEXT;
            S_TILE_NEXT: begin
                        if( pre_pending ) begin

                            code  <= code_next;
                            xpos  <= xoffs_wide[8:0];
                            ysub  <= ysub_w;
                            hzoom <= zoomx;
                            hflip <= flipx;
                            color <= color6[4:0];
                            hipri <= color6[5];
                            draw  <= 1'b1;
                            fst   <= S_DRAW;
                        end else fst <= S_DY_NEXT;
                    end
            S_DY_NEXT: begin
                        if( dy_sel == 1'b0 ) begin
                            dy_sel <= 1'b1;
                            fst    <= S_CULL;
                        end else fst <= S_LIST_NEXT;
                    end
            S_LIST_NEXT: begin
                        if( idx == 13'd0 ) fst <= S_IDLE;
                        else begin
                            idx <= idx - 13'd1;
                            fst <= S_LIST_SET;
                        end
                    end
            default: fst <= S_IDLE;
        endcase
    end
end

endmodule
