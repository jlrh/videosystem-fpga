`timescale 1ns/1ps

module jtaerofgt_game(
    `include "jtframe_game_ports.inc"

    , input dwnld_busy
);

wire vblank_irq;

wire rotate_active = ~status[2];

jtaerofgt_main u_main(
    .rst          ( rst          ),
    .clk          ( clk          ),

    .dip_pause    ( dip_pause    ),
    .vblank_irq   ( vblank_irq   ),

    .joystick1    ( joystick1[5:0] ),
    .joystick2    ( joystick2[5:0] ),
    .cab_1p       ( cab_1p       ),
    .coin         ( coin         ),
    .service      ( service      ),
    .dipsw        ( dipsw[15:0]  ),

    .main_cs      ( main_cs      ),
    .main_addr    ( main_addr    ),
    .main_data    ( main_data    ),
    .main_ok      ( main_ok      ),

    .ram_vaddr    ( ram_vaddr    ),
    .ram_vq       ( ram_vq       ),
    .vram0_vaddr  ( vram0_vaddr  ),
    .vram0_vq     ( vram0_vq     ),
    .vram1_vaddr  ( vram1_vaddr  ),
    .vram1_vq     ( vram1_vq     ),
    .pal_vaddr    ( pal_vaddr    ),
    .pal_vq       ( pal_vq       ),
    .pal1_vaddr   ( pal1_vaddr   ),
    .pal1_vq      ( pal1_vq      ),
    .pal2_vaddr   ( pal2_vaddr   ),
    .pal2_vq      ( pal2_vq      ),
    .sprlook_vaddr( sprlook_vaddr),
    .sprlook_vq   ( sprlook_vq   ),
    .spr_vaddr    ( spr_vaddr    ),
    .spr_vq       ( spr_vq       ),

    .gfxbank_flat ( gfxbank_flat ),
    .scrolly0     ( scrolly0     ),
    .scrolly1     ( scrolly1     ),

    .sndlatch_data    ( sndlatch_data    ),
    .sndlatch_we      ( sndlatch_we      ),
    .sndlatch_pending ( sndlatch_pending ),
    .dbg_view         ( main_dbg_view    )
);

wire [ 7:0] sndlatch_data;
wire        sndlatch_we, sndlatch_pending;
wire [ 7:0] main_dbg_view;

wire [11:1] ram_vaddr;
wire [15:0] ram_vq;
wire [12:1] vram0_vaddr;
wire [15:0] vram0_vq;
wire [12:1] vram1_vaddr;
wire [15:0] vram1_vq;
wire [10:1] pal_vaddr;
wire [15:0] pal_vq;
wire [10:1] pal1_vaddr;
wire [15:0] pal1_vq;
wire [10:1] pal2_vaddr;
wire [15:0] pal2_vq;
wire [14:1] sprlook_vaddr;
wire [15:0] sprlook_vq;
wire [12:1] spr_vaddr;
wire [15:0] spr_vq;
wire [63:0] gfxbank_flat;
wire [15:0] scrolly0, scrolly1;

wire [7:0] dbg_tilebuf;
wire [8:0] dbg_scrollx0, dbg_scrollx1;

jtaerofgt_video u_video(
    .rst          ( rst          ),
    .clk          ( clk          ),
    .dwnld_busy   ( dwnld_busy   ),
    .dbg_tilebuf  ( dbg_tilebuf  ),
    .dbg_scrollx0 ( dbg_scrollx0 ),
    .dbg_scrollx1 ( dbg_scrollx1 ),

    .pxl_cen      ( pxl_cen      ),
    .pxl2_cen     ( pxl2_cen     ),

    .red          ( red          ),
    .green        ( green        ),
    .blue         ( blue         ),
    .HS           ( HS           ),
    .VS           ( VS           ),
    .LHBL         ( LHBL         ),
    .LVBL         ( LVBL         ),
    .vblank_irq   ( vblank_irq   ),

    .vram0_vaddr  ( vram0_vaddr  ),
    .vram0_vq     ( vram0_vq     ),
    .vram1_vaddr  ( vram1_vaddr  ),
    .vram1_vq     ( vram1_vq     ),
    .ram_vaddr    ( ram_vaddr    ),
    .ram_vq       ( ram_vq       ),
    .pal_vaddr    ( pal_vaddr    ),
    .pal_vq       ( pal_vq       ),
    .pal1_vaddr   ( pal1_vaddr   ),
    .pal1_vq      ( pal1_vq      ),
    .gfxbank_flat ( gfxbank_flat ),
    .scrolly0     ( scrolly0     ),
    .scrolly1     ( scrolly1     ),

    .flip         ( ~dipsw[8] & ~rotate_active ),

    .chr_addr     ( chr_addr     ),
    .chr_cs       ( chr_cs       ),

    .chr_data     ( chr_data     ),
    .chr_ok       ( chr_ok       ),
    .chr2_addr    ( chr2_addr    ),
    .chr2_cs      ( chr2_cs      ),
    .chr2_data    ( chr2_data    ),
    .chr2_ok      ( chr2_ok      ),

    .spr_vaddr    ( spr_vaddr    ),
    .spr_vq       ( spr_vq       ),
    .sprlook_vaddr( sprlook_vaddr),
    .sprlook_vq   ( sprlook_vq   ),
    .obj_addr     ( obj_addr     ),
    .obj_cs       ( obj_cs       ),

    .obj_data     ( obj_data     ),
    .obj_ok       ( obj_ok       ),
    .obj2_addr    ( obj2_addr    ),
    .obj2_cs      ( obj2_cs      ),
    .obj2_data    ( obj2_data    ),
    .obj2_ok      ( obj2_ok      ),
    .pal2_vaddr   ( pal2_vaddr   ),
    .pal2_vq      ( pal2_vq      )
);

wire signed [15:0] snd_mono;
jtaerofgt_sound u_sound(
    .rst              ( rst              ),
    .clk              ( clk              ),

    .sndlatch_data    ( sndlatch_data    ),
    .sndlatch_we      ( sndlatch_we      ),
    .sndlatch_pending ( sndlatch_pending ),

    .snd_cs           ( snd_cs           ),
    .snd_addr         ( snd_addr         ),
    .snd_data         ( snd_data         ),
    .snd_ok           ( snd_ok           ),

    .pcma_cs          ( pcma_cs          ),
    .pcma_addr        ( pcma_addr        ),
    .pcma_data        ( pcma_data        ),

    .pcmb_cs          ( pcmb_cs          ),
    .pcmb_addr        ( pcmb_addr        ),
    .pcmb_data        ( pcmb_data        ),

    .snd              ( snd_mono         ),
    .sample           ( sample           ),
    .dbg_view         ( snd_dbg_view     )
);
wire [7:0] snd_dbg_view;

`ifdef JTFRAME_STEREO
assign snd_left  = snd_mono;
assign snd_right = snd_mono;
`else
assign snd = snd_mono;
`endif

assign dip_flip   = dipsw[8];

reg dbg_chr_ok, dbg_obj_ok, dbg_chr_nz, dbg_obj_nz, dbg_chr_vary, dbg_obj_vary;
reg [15:0] dbg_chr_first, dbg_obj_first;
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        {dbg_chr_ok,dbg_obj_ok,dbg_chr_nz,dbg_obj_nz,dbg_chr_vary,dbg_obj_vary} <= 6'd0;
        dbg_chr_first <= 16'd0;
        dbg_obj_first <= 16'd0;
    end else begin
        if( chr_ok ) dbg_chr_ok <= 1'b1;
        if( obj_ok  ) dbg_obj_ok <= 1'b1;
        if( chr_ok && chr_data!=16'd0 ) begin
            dbg_chr_nz <= 1'b1;
            if( !dbg_chr_nz ) dbg_chr_first <= chr_data;
            else if( chr_data!=dbg_chr_first ) dbg_chr_vary <= 1'b1;
        end
        if( obj_ok && obj_data!=16'd0 ) begin
            dbg_obj_nz <= 1'b1;
            if( !dbg_obj_nz ) dbg_obj_first <= obj_data;
            else if( obj_data!=dbg_obj_first ) dbg_obj_vary <= 1'b1;
        end
    end
end
wire [7:0] video_dbg_view = { dbg_chr_ok, dbg_chr_nz, dbg_chr_vary, 1'b0,
                               dbg_obj_ok, dbg_obj_nz, dbg_obj_vary, 1'b0 };

assign debug_view = debug_bus[2] ?
                        (debug_bus[1] ? (debug_bus[0] ? {7'd0,dbg_scrollx1[8]} : dbg_scrollx1[7:0])
                                      : (debug_bus[0] ? {7'd0,dbg_scrollx0[8]} : dbg_scrollx0[7:0])) :
                     debug_bus[1] ? (debug_bus[0] ? dbg_tilebuf : video_dbg_view) :
                     debug_bus[0] ? snd_dbg_view : main_dbg_view;

endmodule
