`timescale 1ns/1ps

module jtaerofgt_video #(

    parameter PFDEPTH = 2,

    parameter SPRPIPE = 3
)(
    input               rst,
    input               clk,

    output              pxl_cen,
    output              pxl2_cen,

    output       [4:0]  red,
    output       [4:0]  green,
    output       [4:0]  blue,
    output              HS,
    output              VS,
    output              LHBL,
    output              LVBL,
    output              vblank_irq,

    input                dwnld_busy,

    output       [8:0]  dbg_hcnt,
    output       [8:0]  dbg_vcnt,
    output       [7:0]  dbg_tilebuf,

    output       [8:0]  dbg_scrollx0,
    output       [8:0]  dbg_scrollx1,

    output      [12:1]  vram0_vaddr,
    input       [15:0]  vram0_vq,

    output      [12:1]  vram1_vaddr,
    input       [15:0]  vram1_vq,

    output      [11:1]  ram_vaddr,
    input       [15:0]  ram_vq,

    output      [10:1]  pal_vaddr,
    input       [15:0]  pal_vq,

    output      [10:1]  pal1_vaddr,
    input       [15:0]  pal1_vq,

    input       [63:0]  gfxbank_flat,

    input                flip,

    input       [15:0]  scrolly0,
    input       [15:0]  scrolly1,

    output      [19:1]  chr_addr,
    output reg          chr_cs,
    input       [15:0]  chr_data,
    input               chr_ok,

    output      [19:1]  chr2_addr,
    output reg          chr2_cs,
    input       [15:0]  chr2_data,
    input               chr2_ok,

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

    output      [10:1]  pal2_vaddr,
    input       [15:0]  pal2_vq
);

wire [8:0] hcnt, vcnt;
wire       HS_raw, VS_raw, LHBL_raw, LVBL_raw;

jtaerofgt_video_timing u_timing(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .pxl_cen    ( pxl_cen    ),
    .pxl2_cen   ( pxl2_cen   ),
    .hcnt       ( hcnt       ),
    .vcnt       ( vcnt       ),
    .HS         ( HS_raw     ),
    .VS         ( VS_raw     ),
    .LHBL       ( LHBL_raw   ),
    .LVBL       ( LVBL_raw   ),
    .vblank_irq ( vblank_irq )
);

localparam VTOTAL = 256;

localparam HTOTAL = 456;

localparam HVIS = 320, VVIS = 224;

reg  [8:0] scrollx0, scrollx1;
reg  [1:0] scx_ph, scx_ph_d;
assign ram_vaddr = (scx_ph==2'd2) ? 11'h200 : 11'h000;
always @(posedge clk, posedge rst)
    if( rst ) begin
        scx_ph   <= 2'd0;
        scx_ph_d <= 2'd0;
        scrollx0 <= 9'd0;
        scrollx1 <= 9'd0;
    end else begin
        scx_ph_d <= scx_ph;
        if( vblank_irq )       scx_ph <= 2'd1;
        else if( scx_ph==2'd1 ) scx_ph <= 2'd2;
        else if( scx_ph==2'd2 ) scx_ph <= 2'd0;

        if( scx_ph_d==2'd1 ) scrollx0 <= ram_vq[8:0] - 9'd18;
        if( scx_ph_d==2'd2 ) scrollx1 <= ram_vq[8:0] - 9'd20;
    end
assign dbg_scrollx0 = scrollx0;
assign dbg_scrollx1 = scrollx1;

localparam FLIPPIVOT0 = 9'd348, FLIPPIVOT1 = 9'd352;
wire [8:0] hcnt_eff0    = flip ? (FLIPPIVOT0-hcnt) : hcnt;
wire [8:0] hcnt_eff1    = flip ? (FLIPPIVOT1-hcnt) : hcnt;
wire [8:0] world_x     = hcnt_eff0 + scrollx0;
wire [5:0] cur_tile_col= world_x[8:3];
wire [2:0] col_in_tile = world_x[2:0];

wire [8:0] world_x0     = (flip ? FLIPPIVOT0 : 9'd0) + scrollx0;

wire [8:0] world_x1     = hcnt_eff1 + scrollx1;
wire [5:0] cur_tile_col1= world_x1[8:3];
wire [2:0] col_in_tile1 = world_x1[2:0];
wire [8:0] world_x0_1   = (flip ? FLIPPIVOT1 : 9'd0) + scrollx1;

function [5:0] col_adv(input [5:0] x);
    col_adv = flip ? (x - 6'd1) : (x + 6'd1);
endfunction
function [5:0] col_rev(input [5:0] x);
    col_rev = flip ? (x + 6'd1) : (x - 6'd1);
endfunction

wire [8:0] vcnt_eff     = flip ? (VVIS-1-vcnt) : vcnt;
wire [8:0] world_y0     = vcnt_eff + scrolly0[8:0];
wire [5:0] tile_row0    = world_y0[8:3];
wire [2:0] row_in_tile0 = world_y0[2:0];
wire [8:0] world_y1     = vcnt_eff + scrolly1[8:0];
wire [5:0] tile_row1    = world_y1[8:3];
wire [2:0] row_in_tile1 = world_y1[2:0];

wire [8:0] vcnt_next     = (vcnt == VTOTAL-1) ? 9'd0 : vcnt + 9'd1;
wire [8:0] vcnt_next_eff = flip ? (VVIS-1-vcnt_next) : vcnt_next;
wire [8:0] world_y0_next = vcnt_next_eff + scrolly0[8:0];
wire [5:0] tile_row0_next= world_y0_next[8:3];
wire [2:0] row_in_next0  = world_y0_next[2:0];
wire [8:0] world_y1_next = vcnt_next_eff + scrolly1[8:0];
wire [5:0] tile_row1_next= world_y1_next[8:3];
wire [2:0] row_in_next1  = world_y1_next[2:0];
wire       line_prime    = pxl_cen && hcnt == 9'd336;

wire       boundary       = pxl_cen && ( (LHBL_raw && col_in_tile==(flip?3'b000:3'b111)) || hcnt==HTOTAL-1 );
wire       boundary_line  = hcnt==HTOTAL-1;

wire       boundary1      = pxl_cen && ( (LHBL_raw && col_in_tile1==(flip?3'b000:3'b111)) || hcnt==HTOTAL-1 );

reg [31:0] row_disp;
reg [ 2:0] color_disp;
reg [31:0] rowb   [0:1];
reg [ 2:0] colorb [0:1];
reg [ 5:0] colb   [0:1];
reg [ 1:0] rdyb;
reg        rd_sel;
reg        wr_sel;
reg [ 5:0] want_col;

function NEXT_SEL(input s);
    NEXT_SEL = (PFDEPTH==2) ? ~s : 1'b0;
endfunction

reg        swap_pending;
`ifdef SIMULATION
reg  [7:0] dbg_skip_cnt;
reg        dbg_trace_video;
initial dbg_trace_video = $test$plusargs("trace_video");

reg [31:0] dbg_cyc;
reg [31:0] dbg_fetch_t0,  dbg_fetch_min,  dbg_fetch_max,  dbg_fetch_sum,  dbg_fetch_cnt;
reg [31:0] dbg_fetch_t0_1,dbg_fetch_min_1,dbg_fetch_max_1,dbg_fetch_sum_1,dbg_fetch_cnt_1;
always @(posedge clk, posedge rst)
    if( rst ) dbg_cyc <= 32'd0;
    else      dbg_cyc <= dbg_cyc + 32'd1;
`endif

localparam S_IDLE=0, S_VWAIT=1, S_VDEC=2, S_G0=3, S_G1=4;
reg [2:0]  fst;
reg [5:0]  fetch_col, fetch_row;
reg [2:0]  fetch_rowin;
reg [19:1] f_addr;

assign vram0_vaddr = { fetch_row, fetch_col };
assign chr_addr    = f_addr;

wire       use_next_row  = hcnt >= 9'd336;
wire [5:0] f_row_sel     = use_next_row ? tile_row0_next : tile_row0;
wire [2:0] f_rowin_sel   = use_next_row ? row_in_next0   : row_in_tile0;

wire [5:0] want_col_now  = boundary ? ( boundary_line ? world_x0[8:3] : col_adv(cur_tile_col) )
                                    : want_col;
wire       buf_match     = rdyb[rd_sel] && colb[rd_sel]==want_col_now;
wire       buf_stale     = rdyb[rd_sel] && colb[rd_sel]!=want_col_now;

reg  [3:0] dbg_nrdy_cnt, dbg_nrdy_max, dbg_colerr;
wire       dbg_eol   = pxl_cen && hcnt==HTOTAL-1;
wire       dbg_eof   = pxl_cen && hcnt==9'd0 && vcnt==9'd0;
wire       dbg_sol   = pxl_cen && hcnt==9'd0 && LVBL_raw;
wire [5:0] dbg_diff  = colb[rd_sel] - world_x0[8:3];
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dbg_nrdy_cnt <= 4'd0; dbg_nrdy_max <= 4'd0; dbg_colerr <= 4'd0;
    end else begin
        if( dbg_eof ) dbg_nrdy_max <= 4'd0;

        if( dbg_sol && dbg_diff!=6'd0 && dbg_colerr==4'd0 )
            dbg_colerr <= dbg_diff[3:0];
        if( dbg_eof ) dbg_colerr <= 4'd0;
        if( dbg_eol ) begin
            if( dbg_nrdy_cnt > dbg_nrdy_max ) dbg_nrdy_max <= dbg_nrdy_cnt;
            dbg_nrdy_cnt <= 4'd0;
        end else if( boundary ) begin
            if( !rdyb[rd_sel] && dbg_nrdy_cnt!=4'hf ) dbg_nrdy_cnt <= dbg_nrdy_cnt + 4'd1;
        end
    end
end

assign dbg_tilebuf = { dbg_nrdy_max, dbg_colerr };

wire [5:0] need0 = swap_pending ? want_col_now : col_adv(want_col_now);
wire [5:0] need1 = col_adv(need0);
wire       have0 = (rdyb[0] && colb[0]==need0) || (rdyb[1] && colb[1]==need0);
wire [5:0] tgt_col = have0 ? need1 : need0;

wire [1:0]  bank_idx  = vram0_vq[12:11];
wire [7:0]  bank_byte = (bank_idx==2'd0) ? gfxbank_flat[15: 8] :
                         (bank_idx==2'd1) ? gfxbank_flat[ 7: 0] :
                         (bank_idx==2'd2) ? gfxbank_flat[31:24] :
                                            gfxbank_flat[23:16];
wire [18:0] vdec_code  = { bank_byte, vram0_vq[10:0] };
wire [ 2:0] vdec_color = vram0_vq[15:13];

wire [23:0] byte_addr  = { vdec_code, 5'b0 } + { 19'd0, fetch_rowin, 2'b0 };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        fst             <= S_IDLE;
        chr_cs          <= 1'b0;
        row_disp        <= 32'd0;
        color_disp      <= 3'd0;
        rowb[0]         <= 32'd0;  rowb[1]   <= 32'd0;
        colorb[0]       <= 3'd0;   colorb[1] <= 3'd0;
        colb[0]         <= 6'd0;   colb[1]   <= 6'd0;
        rdyb            <= 2'b00;
        rd_sel          <= 1'b0;
        wr_sel          <= 1'b0;
        want_col        <= 6'd0;
        swap_pending    <= 1'b0;
`ifdef SIMULATION
        dbg_skip_cnt  <= 8'd0;
        dbg_fetch_t0  <= 32'd0;
        dbg_fetch_min <= 32'hFFFF_FFFF;
        dbg_fetch_max <= 32'd0;
        dbg_fetch_sum <= 32'd0;
        dbg_fetch_cnt <= 32'd0;
`endif
    end else begin
`ifdef SIMULATION
        if (dbg_trace_video && vblank_irq && dbg_fetch_cnt>0)
            $display("VIDFETCH layer=0 min=%0d max=%0d avg=%0d cnt=%0d", dbg_fetch_min, dbg_fetch_max, dbg_fetch_sum/dbg_fetch_cnt, dbg_fetch_cnt);
`endif

        if( boundary ) want_col <= want_col_now;
        if( boundary || swap_pending ) begin
            if( buf_match ) begin
                row_disp     <= rowb[rd_sel];
                color_disp   <= colorb[rd_sel];
                rdyb[rd_sel] <= 1'b0;
                rd_sel       <= NEXT_SEL(rd_sel);
                swap_pending <= 1'b0;
            end else if( buf_stale ) begin
                rdyb[rd_sel] <= 1'b0;
                rd_sel       <= NEXT_SEL(rd_sel);
                swap_pending <= 1'b1;
`ifdef SIMULATION
                dbg_skip_cnt <= dbg_skip_cnt + 8'd1;
                if (dbg_trace_video) $display("VIDBACKPRESS layer=0 vcnt=%0d hcnt=%0d stale=1 want=%0d got=%0d skip_cnt=%0d", vcnt, hcnt, want_col_now, colb[rd_sel], dbg_skip_cnt+8'd1);
`endif
            end else begin
                swap_pending <= 1'b1;
`ifdef SIMULATION
                if( boundary ) begin
                    dbg_skip_cnt <= dbg_skip_cnt + 8'd1;
                    if (dbg_trace_video) $display("VIDBACKPRESS layer=0 vcnt=%0d hcnt=%0d stale=0 want=%0d skip_cnt=%0d", vcnt, hcnt, want_col_now, dbg_skip_cnt+8'd1);
                end
`endif
            end
        end

        if( line_prime ) begin
            fst          <= S_IDLE;
            chr_cs       <= 1'b0;
            rdyb         <= 2'b00;
            rd_sel       <= 1'b0;
            wr_sel       <= 1'b0;

            want_col     <= col_rev(world_x0[8:3]);
            swap_pending <= 1'b0;
        end else
        case( fst )

            S_IDLE: if( !rdyb[wr_sel] ) begin

                        fetch_col     <= tgt_col;
                        fetch_row     <= f_row_sel;
                        fetch_rowin   <= f_rowin_sel;
                        colb[wr_sel]  <= tgt_col;
                        fst           <= S_VWAIT;
`ifdef SIMULATION
                        dbg_fetch_t0 <= dbg_cyc;
`endif
                    end
            S_VWAIT: fst <= S_VDEC;

            S_VDEC: begin

                        f_addr          <= byte_addr[19:1];
                        chr_cs          <= 1'b1;
                        colorb[wr_sel]  <= vdec_color;
                        fst             <= S_G0;
                    end
            S_G0: if( chr_ok ) begin
                        rowb[wr_sel][15:8] <= chr_data[15:8];
                        rowb[wr_sel][ 7:0] <= chr_data[ 7:0];
                        f_addr             <= f_addr + 19'd1;
                        fst                <= S_G1;
                    end
            S_G1: if( chr_ok ) begin
                        rowb[wr_sel][31:24] <= chr_data[15:8];
                        rowb[wr_sel][23:16] <= chr_data[ 7:0];
                        rdyb[wr_sel]        <= 1'b1;
                        wr_sel              <= NEXT_SEL(wr_sel);
                        chr_cs              <= 1'b0;
                        fst                 <= S_IDLE;
`ifdef SIMULATION
                        if( dbg_cyc-dbg_fetch_t0 < dbg_fetch_min ) dbg_fetch_min <= dbg_cyc-dbg_fetch_t0;
                        if( dbg_cyc-dbg_fetch_t0 > dbg_fetch_max ) dbg_fetch_max <= dbg_cyc-dbg_fetch_t0;
                        dbg_fetch_sum <= dbg_fetch_sum + (dbg_cyc-dbg_fetch_t0);
                        dbg_fetch_cnt <= dbg_fetch_cnt + 32'd1;
`endif
                    end
            default: fst <= S_IDLE;
        endcase
    end
end

reg [31:0] row_disp1;
reg [ 2:0] color_disp1;
reg [31:0] rowb1   [0:1];
reg [ 2:0] colorb1 [0:1];
reg [ 5:0] colb1   [0:1];
reg [ 1:0] rdyb1;
reg        rd_sel1, wr_sel1;
reg [ 5:0] want_col1;
reg        swap_pending1;
`ifdef SIMULATION
reg  [7:0] dbg_skip_cnt1;
`endif

reg [2:0]  fst1;
reg [5:0]  fetch_col1, fetch_row1;
reg [2:0]  fetch_rowin1;
reg [19:1] f_addr1;

assign vram1_vaddr = { fetch_row1, fetch_col1 };
assign chr2_addr   = f_addr1;

wire [5:0] f_row_sel1    = use_next_row ? tile_row1_next : tile_row1;
wire [2:0] f_rowin_sel1  = use_next_row ? row_in_next1   : row_in_tile1;
wire [5:0] want_col1_now = boundary1 ? ( boundary_line ? world_x0_1[8:3] : col_adv(cur_tile_col1) )
                                     : want_col1;
wire       buf_match1    = rdyb1[rd_sel1] && colb1[rd_sel1]==want_col1_now;
wire       buf_stale1    = rdyb1[rd_sel1] && colb1[rd_sel1]!=want_col1_now;

wire [5:0] need0_1 = swap_pending1 ? want_col1_now : col_adv(want_col1_now);
wire [5:0] need1_1 = col_adv(need0_1);
wire       have0_1 = (rdyb1[0] && colb1[0]==need0_1) || (rdyb1[1] && colb1[1]==need0_1);
wire [5:0] tgt_col1 = have0_1 ? need1_1 : need0_1;

wire [1:0]  bank_idx1  = vram1_vq[12:11];
wire [7:0]  bank_byte1 = (bank_idx1==2'd0) ? gfxbank_flat[47:40] :
                          (bank_idx1==2'd1) ? gfxbank_flat[39:32] :
                          (bank_idx1==2'd2) ? gfxbank_flat[63:56] :
                                              gfxbank_flat[55:48];
wire [18:0] vdec_code1  = { bank_byte1, vram1_vq[10:0] };
wire [ 2:0] vdec_color1 = vram1_vq[15:13];
wire [23:0] byte_addr1  = { vdec_code1, 5'b0 } + { 19'd0, fetch_rowin1, 2'b0 };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        fst1             <= S_IDLE;
        chr2_cs          <= 1'b0;
        row_disp1        <= 32'd0;
        color_disp1      <= 3'd0;
        rowb1[0]         <= 32'd0;  rowb1[1]   <= 32'd0;
        colorb1[0]       <= 3'd0;   colorb1[1] <= 3'd0;
        colb1[0]         <= 6'd0;   colb1[1]   <= 6'd0;
        rdyb1            <= 2'b00;
        rd_sel1          <= 1'b0;
        wr_sel1          <= 1'b0;
        want_col1        <= 6'd0;
        swap_pending1    <= 1'b0;
`ifdef SIMULATION
        dbg_skip_cnt1   <= 8'd0;
        dbg_fetch_t0_1  <= 32'd0;
        dbg_fetch_min_1 <= 32'hFFFF_FFFF;
        dbg_fetch_max_1 <= 32'd0;
        dbg_fetch_sum_1 <= 32'd0;
        dbg_fetch_cnt_1 <= 32'd0;
`endif
    end else begin
`ifdef SIMULATION
        if (dbg_trace_video && vblank_irq && dbg_fetch_cnt_1>0)
            $display("VIDFETCH layer=1 min=%0d max=%0d avg=%0d cnt=%0d", dbg_fetch_min_1, dbg_fetch_max_1, dbg_fetch_sum_1/dbg_fetch_cnt_1, dbg_fetch_cnt_1);
`endif

        if( boundary1 ) want_col1 <= want_col1_now;
        if( boundary1 || swap_pending1 ) begin
            if( buf_match1 ) begin
                row_disp1      <= rowb1[rd_sel1];
                color_disp1    <= colorb1[rd_sel1];
                rdyb1[rd_sel1] <= 1'b0;
                rd_sel1        <= NEXT_SEL(rd_sel1);
                swap_pending1  <= 1'b0;
            end else if( buf_stale1 ) begin
                rdyb1[rd_sel1] <= 1'b0;
                rd_sel1        <= NEXT_SEL(rd_sel1);
                swap_pending1  <= 1'b1;
`ifdef SIMULATION
                dbg_skip_cnt1 <= dbg_skip_cnt1 + 8'd1;
                if (dbg_trace_video) $display("VIDBACKPRESS layer=1 vcnt=%0d hcnt=%0d stale=1 want=%0d got=%0d skip_cnt=%0d", vcnt, hcnt, want_col1_now, colb1[rd_sel1], dbg_skip_cnt1+8'd1);
`endif
            end else begin
                swap_pending1 <= 1'b1;
`ifdef SIMULATION
                if( boundary1 ) begin
                    dbg_skip_cnt1 <= dbg_skip_cnt1 + 8'd1;
                    if (dbg_trace_video) $display("VIDBACKPRESS layer=1 vcnt=%0d hcnt=%0d stale=0 want=%0d skip_cnt=%0d", vcnt, hcnt, want_col1_now, dbg_skip_cnt1+8'd1);
                end
`endif
            end
        end

        if( line_prime ) begin
            fst1          <= S_IDLE;
            chr2_cs       <= 1'b0;
            rdyb1         <= 2'b00;
            rd_sel1       <= 1'b0;
            wr_sel1       <= 1'b0;
            want_col1     <= col_rev(world_x0_1[8:3]);
            swap_pending1 <= 1'b0;
        end else
        case( fst1 )

            S_IDLE: if( !rdyb1[wr_sel1] ) begin
                        fetch_col1     <= tgt_col1;
                        fetch_row1     <= f_row_sel1;
                        fetch_rowin1   <= f_rowin_sel1;
                        colb1[wr_sel1] <= tgt_col1;
                        fst1           <= S_VWAIT;
`ifdef SIMULATION
                        dbg_fetch_t0_1 <= dbg_cyc;
`endif
                    end
            S_VWAIT: fst1 <= S_VDEC;

            S_VDEC: begin
                        f_addr1          <= byte_addr1[19:1];
                        chr2_cs          <= 1'b1;
                        colorb1[wr_sel1] <= vdec_color1;
                        fst1             <= S_G0;
                    end
            S_G0: if( chr2_ok ) begin
                        rowb1[wr_sel1][15:8] <= chr2_data[15:8];
                        rowb1[wr_sel1][ 7:0] <= chr2_data[ 7:0];
                        f_addr1              <= f_addr1 + 19'd1;
                        fst1                 <= S_G1;
                    end
            S_G1: if( chr2_ok ) begin
                        rowb1[wr_sel1][31:24] <= chr2_data[15:8];
                        rowb1[wr_sel1][23:16] <= chr2_data[ 7:0];
                        rdyb1[wr_sel1]        <= 1'b1;
                        wr_sel1               <= NEXT_SEL(wr_sel1);
                        chr2_cs               <= 1'b0;
                        fst1                  <= S_IDLE;
`ifdef SIMULATION
                        if( dbg_cyc-dbg_fetch_t0_1 < dbg_fetch_min_1 ) dbg_fetch_min_1 <= dbg_cyc-dbg_fetch_t0_1;
                        if( dbg_cyc-dbg_fetch_t0_1 > dbg_fetch_max_1 ) dbg_fetch_max_1 <= dbg_cyc-dbg_fetch_t0_1;
                        dbg_fetch_sum_1 <= dbg_fetch_sum_1 + (dbg_cyc-dbg_fetch_t0_1);
                        dbg_fetch_cnt_1 <= dbg_fetch_cnt_1 + 32'd1;
`endif
                    end
            default: fst1 <= S_IDLE;
        endcase
    end
end

wire [7:0] row_byte = col_in_tile[2:1]==2'd0 ? row_disp[15: 8] :
                      col_in_tile[2:1]==2'd1 ? row_disp[ 7: 0] :
                      col_in_tile[2:1]==2'd2 ? row_disp[31:24] :
                                                row_disp[23:16];
wire [3:0] nibble = col_in_tile[0] ? row_byte[3:0] : row_byte[7:4];
assign pal_vaddr  = { 3'b000, color_disp, nibble };

wire [7:0] row_byte1 = col_in_tile1[2:1]==2'd0 ? row_disp1[15: 8] :
                       col_in_tile1[2:1]==2'd1 ? row_disp1[ 7: 0] :
                       col_in_tile1[2:1]==2'd2 ? row_disp1[31:24] :
                                                  row_disp1[23:16];
wire [3:0] nibble1 = col_in_tile1[0] ? row_byte1[3:0] : row_byte1[7:4];
assign pal1_vaddr  = { 3'b010, color_disp1, nibble1 };

wire       trans1 = nibble1 == 4'hF;

wire [9:0] spr_pxl;
wire       spr_vld;

jtaerofgt_sprites #(.SPRPIPE(SPRPIPE)) u_sprites(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .pxl_cen        ( pxl_cen       ),
    .hcnt           ( hcnt          ),
    .vcnt           ( vcnt          ),
    .LHBL           ( LHBL_raw      ),
    .flip           ( flip          ),
    .spr_vaddr      ( spr_vaddr     ),
    .spr_vq         ( spr_vq        ),
    .sprlook_vaddr  ( sprlook_vaddr ),
    .sprlook_vq     ( sprlook_vq    ),
    .obj_addr       ( obj_addr      ),
    .obj_cs         ( obj_cs        ),
    .obj_data       ( obj_data      ),
    .obj_ok         ( obj_ok        ),
    .obj2_addr      ( obj2_addr     ),
    .obj2_cs        ( obj2_cs       ),
    .obj2_data      ( obj2_data     ),
    .obj2_ok        ( obj2_ok       ),
    .pxl            ( spr_pxl       ),
    .pxl_vld        ( spr_vld       )
);

assign pal2_vaddr = { 1'b1, spr_pxl[8:4], spr_pxl[3:0] };
wire   spr_hipri  = spr_pxl[9];

wire   spr_shown  = spr_vld && (spr_hipri || trans1);

reg HS_d, VS_d, LHBL_d, LVBL_d;
reg [4:0] red_r, green_r, blue_r;
reg [8:0] hcnt_d, vcnt_d;
always @(posedge clk) if( pxl_cen ) begin
    HS_d    <= HS_raw;
    VS_d    <= VS_raw;
    LHBL_d  <= LHBL_raw;
    LVBL_d  <= LVBL_raw;
    hcnt_d  <= hcnt;
    vcnt_d  <= vcnt;

    red_r   <= (LHBL_raw && LVBL_raw && !dwnld_busy) ? (spr_shown ? pal2_vq[14:10] : trans1 ? pal_vq[14:10] : pal1_vq[14:10]) : 5'd0;
    green_r <= (LHBL_raw && LVBL_raw && !dwnld_busy) ? (spr_shown ? pal2_vq[ 9: 5] : trans1 ? pal_vq[ 9: 5] : pal1_vq[ 9: 5]) : 5'd0;
    blue_r  <= (LHBL_raw && LVBL_raw && !dwnld_busy) ? (spr_shown ? pal2_vq[ 4: 0] : trans1 ? pal_vq[ 4: 0] : pal1_vq[ 4: 0]) : 5'd0;
end
assign HS    = HS_d;
assign VS    = VS_d;
assign LHBL  = LHBL_d;
assign LVBL  = LVBL_d;
assign red   = red_r;
assign green = green_r;
assign blue  = blue_r;
assign dbg_hcnt = hcnt_d;
assign dbg_vcnt = vcnt_d;

endmodule
