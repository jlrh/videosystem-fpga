`ifndef JTFRAME_COLORW
`define JTFRAME_COLORW 4
`endif

`ifndef JTFRAME_BUTTONS
`define JTFRAME_BUTTONS 2
`endif

module jtaerofgt_game_sdram(
    `include "jtframe_common_ports.inc"
    `include "jtframe_mem_ports.inc"
);

/* verilator lint_off WIDTH */
localparam [25:0] BA1_START  =`ifdef JTFRAME_BA1_START  `JTFRAME_BA1_START  `else 26'd0 `endif;
localparam [25:0] BA2_START  =`ifdef JTFRAME_BA2_START  `JTFRAME_BA2_START  `else 26'd0 `endif;
localparam [25:0] BA3_START  =`ifdef JTFRAME_BA3_START  `JTFRAME_BA3_START  `else 26'd0 `endif;
localparam [25:0] PROM_START =`ifdef JTFRAME_PROM_START `JTFRAME_PROM_START `else 26'd0 `endif;
localparam [25:0] HEADER_LEN =`ifdef JTFRAME_HEADER     `JTFRAME_HEADER     `else 26'd0 `endif;
localparam        SDRAMW     =`ifdef JTFRAME_SDRAM_LARGE 24 `else 23 `endif;
/* verilator lint_on WIDTH */

parameter SND_OFFSET = (`SND_START)>>1;
parameter OBJ2_OFFSET = (`OBJ2_START-`OBJ_START)>>1;
parameter PCMA_OFFSET = (`PCMA_START-`PCMB_START)>>1;

wire mute;

wire [18:1] main_addr;
wire [15:0] main_data;
wire        main_cs, main_ok;
wire [16:0] snd_addr;
wire [ 7:0] snd_data;
wire        snd_cs, snd_ok;
wire [19:1] chr_addr;
wire [15:0] chr_data;
wire        chr_cs, chr_ok;
wire [19:1] chr2_addr;
wire [15:0] chr2_data;
wire        chr2_cs, chr2_ok;
wire [19:1] obj_addr;
wire [15:0] obj_data;
wire        obj_cs, obj_ok;
wire [18:1] obj2_addr;
wire [15:0] obj2_data;
wire        obj2_cs, obj2_ok;
wire [17:0] pcmb_addr;
wire [ 7:0] pcmb_data;
wire        pcmb_cs, pcmb_ok;
wire [19:0] pcma_addr;
wire [ 7:0] pcma_data;
wire        pcma_cs, pcma_ok;
wire        prom_we, header;
wire [SDRAMW-2:0] raw_addr, post_addr;
wire [SDRAMW-2:0] ioctl_prog_addr   = ioctl_addr[SDRAMW-2:0];
wire [25:0] pre_addr, dwnld_addr, ioctl_addr_noheader;
wire [ 7:0] post_data;
wire [15:0] raw_data;
wire [ 7:0] pcb_id;
wire        pass_io;

wire gfx4_en, gfx8_en, gfx16_en, gfx16b_en, gfx16c_en, ioctl_dwn;

assign pass_io = header | ioctl_ram;
assign ioctl_addr_noheader = `ifdef JTFRAME_HEADER header ? ioctl_addr : ioctl_addr - HEADER_LEN `else ioctl_addr `endif ;
`ifdef JTFRAME_SDRAM_CACHE
assign burst_addr = { (SDRAMW-1){1'b0} };
assign burst_ba   = 2'd0;
assign burst_rd   = 1'b0;
assign burst_wr   = 1'b0;
assign burst_din  = 16'd0;
`endif

wire rst_h, rst24_h, rst48_h, hold_rst;

/* verilator tracing_off */
jtframe_rsthold u_hold(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .hold   ( hold_rst  ),
    .rst_h  ( rst_h     ),
    .rst24  ( rst24     ),
    .clk24  ( clk24     ),
    .rst24_h( rst24_h   )
`ifdef JTFRAME_CLK48 ,
    .rst48  ( rst48     ),
    .clk48  ( clk48     ),
    .rst48_h( rst48_h   )
`endif
);
/* verilator tracing_on */
jtaerofgt_game u_game(

    .dwnld_busy ( dwnld_busy ),
    .rst        ( rst_h     ),
    .clk        ( clk       ),
    .rst24      ( rst24_h   ),
    .clk24      ( clk24     ),
`ifdef JTFRAME_CLK48
    .rst48      ( rst48_h   ),
    .clk48      ( clk48     ),
`endif
    .rst96      ( rst96     ),
    .clk96      ( clk96     ),

`ifdef JTFRAME_STEREO
    .snd_left       ( snd_left      ),
    .snd_right      ( snd_right     ),
`else
    .snd            ( snd           ),
`endif
    .sample         ( sample        ),
    .snd_en         ( snd_en        ),
    .snd_vol        ( snd_vol       ),
    .pxl2_cen       ( pxl2_cen      ),
    .pxl_cen        ( pxl_cen       ),
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    .LHBL           ( LHBL          ),
    .LVBL           ( LVBL          ),
    .HS             ( HS            ),
    .VS             ( VS            ),

    .cab_1p   ( cab_1p  ),
    .coin     ( coin    ),
    .joystick1    ( joystick1        ), .joystick2    ( joystick2        ),
    .joystick3    ( joystick3        ), .joystick4    ( joystick4        ), `ifdef JTFRAME_MOUSE
    .mouse_1p     ( mouse_1p         ), .mouse_2p     ( mouse_2p         ), .mouse_strobe ( mouse_strobe ), `endif `ifdef JTFRAME_LIGHTGUN
    .gun_1p_x     ( gun_1p_x         ), .gun_1p_y     ( gun_1p_y         ),
    .gun_2p_x     ( gun_2p_x         ), .gun_2p_y     ( gun_2p_y         ), `endif `ifdef JTFRAME_SPINNER
    .spinner_1p   ( spinner_1p       ), .spinner_2p   ( spinner_2p       ), `endif
    .joyana_l1    ( joyana_l1        ), .joyana_l2    ( joyana_l2        ),
    .joyana_l3    ( joyana_l3        ), .joyana_l4    ( joyana_l4        ),
    .joyana_r1    ( joyana_r1        ), .joyana_r2    ( joyana_r2        ),
    .joyana_r3    ( joyana_r3        ), .joyana_r4    ( joyana_r4        ),
    .dial_x       ( dial_x           ), .dial_y       ( dial_y           ),

    .status         ( status        ),
    .dipsw          ( dipsw         ),
    .service        ( service       ),
    .tilt           ( tilt          ),
    .dip_pause      ( dip_pause     ),
    .dip_flip       ( dip_flip      ),
    .dip_test       ( dip_test      ),
    .dip_fxlevel    ( dip_fxlevel   ),
`ifdef JTFRAME_GAME_UART
    .uart_tx        ( uart_tx       ),
    .uart_rx        ( uart_rx       ),
`endif

    .main_addr ( main_addr ),
    .main_cs   ( main_cs   ),
    .main_ok   ( main_ok   ),
    .main_data ( main_data ),

    .snd_addr ( snd_addr ),
    .snd_cs   ( snd_cs   ),
    .snd_ok   ( snd_ok   ),
    .snd_data ( snd_data ),

    .chr_addr ( chr_addr ),
    .chr_cs   ( chr_cs   ),
    .chr_ok   ( chr_ok   ),
    .chr_data ( chr_data ),

    .chr2_addr ( chr2_addr ),
    .chr2_cs   ( chr2_cs   ),
    .chr2_ok   ( chr2_ok   ),
    .chr2_data ( chr2_data ),

    .obj_addr ( obj_addr ),
    .obj_cs   ( obj_cs   ),
    .obj_ok   ( obj_ok   ),
    .obj_data ( obj_data ),

    .obj2_addr ( obj2_addr ),
    .obj2_cs   ( obj2_cs   ),
    .obj2_ok   ( obj2_ok   ),
    .obj2_data ( obj2_data ),

    .pcmb_addr ( pcmb_addr ),
    .pcmb_cs   ( pcmb_cs   ),
    .pcmb_ok   ( pcmb_ok   ),
    .pcmb_data ( pcmb_data ),

    .pcma_addr ( pcma_addr ),
    .pcma_cs   ( pcma_cs   ),
    .pcma_ok   ( pcma_ok   ),
    .pcma_data ( pcma_data ),

`ifdef JTFRAME_SRAM

    .sram_addr  ( sram_addr     ),
    .sram_din   ( sram_din      ),
    .sram_dout  ( sram_dout     ),
    .sram_wen   ( sram_wen      ),
    .sram_dsn   ( sram_dsn      ),
    .sram_ok    ( sram_ok       ),
`endif

`ifdef JTFRAME_SAVEGAME

    .sav_change ( sav_change    ),
    .sav_wait   ( sav_wait      ),
    .sav_done   ( sav_done      ),
    .sav_wr     ( sav_wr        ),
    .sav_ack    ( sav_ack       ),
    .sav_din    ( sav_din       ),
    .sav_dout   ( sav_dout      ),
    .sav_addr   ( sav_addr      ),
`endif

    .ioctl_addr   ( pass_io ? ioctl_addr       : ioctl_addr_noheader  ),
    .prog_addr    ( pass_io ? ioctl_prog_addr : raw_addr      ),
    .prog_data    ( pass_io ? ioctl_dout       : raw_data[7:0] ),
    .prog_we      ( pass_io ? ioctl_wr         : prog_we       ),
    .prog_ba      ( prog_ba        ),
    .prom_we      ( pass_io ? 1'b0 : prom_we ),
`ifdef JTFRAME_HEADER
    .header       ( header         ),
`endif
`ifdef JTFRAME_IOCTL_RD
    .ioctl_din    ( ioctl_din      ),
    .ioctl_dout   ( ioctl_dout     ),
    .ioctl_wr     ( ioctl_wr       ), `endif
    .ioctl_ram    ( ioctl_ram      ),
    .ioctl_cart   ( ioctl_cart     ),

    .debug_bus    ( debug_bus      ),
    .debug_view   ( debug_view     ),
`ifdef JTFRAME_STATUS
    .st_addr      ( st_addr        ),
    .st_dout      ( st_dout        ),
`endif
`ifdef JTFRAME_LF_BUFFER
    .game_vrender( game_vrender  ),
    .game_hdump  ( game_hdump    ),
    .ln_addr     ( ln_addr       ),
    .ln_data     ( ln_data       ),
    .ln_done     ( ln_done       ),
    .ln_hs       ( ln_hs         ),
    .ln_dout     ( ln_dout       ),
    .ln_pxl      ( ln_pxl        ),
    .ln_v        ( ln_v          ),
    .ln_vs       ( ln_vs         ),
    .ln_lvbl     ( ln_lvbl       ),
    .ln_we       ( ln_we         ),
`ifdef JTFRAME_LF_ZOOM
    .h_step      ( h_step        ),
    .v_step      ( v_step        ),
`endif
`endif
    .gfx_en      ( gfx_en        )
);
/* verilator tracing_off */
assign dwnld_busy = ioctl_rom | prom_we;
assign dwnld_addr = ioctl_addr;
assign prog_addr = raw_addr;
assign prog_data = raw_data;
assign gfx4_en   = 0;
assign gfx8_en   = 0;
assign gfx16_en  = 0;
assign gfx16b_en = 0;
assign gfx16c_en = 0;
assign ioctl_dwn = ioctl_rom | ioctl_cart;
`ifdef VERILATOR_KEEP_SDRAM /* verilator tracing_on */ `else /* verilator tracing_off */ `endif
jtframe_dwnld #(
    .SDRAMW     ( SDRAMW       ),
`ifdef JTFRAME_HEADER
    .HEADER    ( `JTFRAME_HEADER   ),
`endif
`ifdef JTFRAME_BA1_START
    .BA1_START ( BA1_START ),
`endif
`ifdef JTFRAME_BA2_START
    .BA2_START ( BA2_START ),
`endif
`ifdef JTFRAME_BA3_START
    .BA3_START ( BA3_START ),
`endif
`ifdef JTFRAME_PROM_START
    .PROM_START( PROM_START ),
`endif
    .SWAB      ( 1),
    .GFX8B0    ( 0),
    .GFX16B0   ( 0)
) u_dwnld(
    .clk          ( clk            ),
    .ioctl_rom    ( ioctl_dwn      ),
    .ioctl_addr   ( dwnld_addr     ),
    .ioctl_dout   ( ioctl_dout     ),
    .ioctl_wr     ( ioctl_wr       ),
    .gfx4_en      ( gfx4_en        ),
    .gfx8_en      ( gfx8_en        ),
    .gfx16_en     ( gfx16_en       ),
    .gfx16b_en    ( gfx16b_en      ),
    .gfx16c_en    ( gfx16c_en      ),
    .prog_addr    ( raw_addr       ),
    .prog_data    ( raw_data       ),
    .prog_mask    ( prog_mask      ),
    .prog_we      ( prog_we        ),
    .prog_rd      ( prog_rd        ),
    .prog_ba      ( prog_ba        ),
    .prom_we      ( prom_we        ),
    .header       ( header         ),
    .sdram_ack    ( prog_ack       )
);

jtframe_headerbyte #(.AW(6)) u_pcbid(
    .clk          ( clk            ),
    .header       ( header         ),
    .ioctl_addr   ( ioctl_addr[5:0]),
    .ioctl_dout   ( ioctl_dout     ),
    .ioctl_wr     ( ioctl_wr       ),
    .dout         ( pcb_id         )
);
`ifdef VERILATOR_KEEP_SDRAM /* verilator tracing_on */ `else /* verilator tracing_off */ `endif

jtframe_rom_2slots #(
    .SDRAMW(SDRAMW-1),

    .SLOT0_OKLATCH(0),
    .SLOT0_AW(18),
    .SLOT0_DW(16),

    .SLOT1_OFFSET(SND_OFFSET[SDRAMW-2:0]),
    .SLOT1_OKLATCH(0),
    .SLOT1_AW(17),
    .SLOT1_DW( 8)
`ifdef JTFRAME_BA0_LEN
    ,.SLOT0_DOUBLE(1)
    ,.SLOT1_DOUBLE(1)
`endif
) u_bank0(
    .rst         ( rst        ),
    .clk         ( clk        ),

    .slot0_addr  ( main_addr  ),
    .slot0_dout  ( main_data  ),
    .slot0_cs    ( main_cs    ),
    .slot0_ok    ( main_ok    ),

    .slot1_addr  ( snd_addr  ),
    .slot1_dout  ( snd_data  ),
    .slot1_cs    ( snd_cs    ),
    .slot1_ok    ( snd_ok    ),

    .sdram_ack   ( ba_ack[0]  ),
    .sdram_rd    ( ba_rd[0]   ),
    .sdram_addr  ( ba0_addr   ),
    .data_dst    ( ba_dst[0]  ),
    .data_rdy    ( ba_rdy[0]  ),
    .data_read   ( data_read  )
);
assign ba_wr[0] = 0;
assign ba0_din  = 0;
assign ba0_dsn  = 3;
jtframe_rom_2slots #(
    .SDRAMW(SDRAMW-1),

    .SLOT0_OKLATCH(0),
    .SLOT0_AW(19),
    .SLOT0_DW(16),

    .SLOT1_OKLATCH(0),
    .SLOT1_AW(19),
    .SLOT1_DW(16)
`ifdef JTFRAME_BA1_LEN
    ,.SLOT0_DOUBLE(1)
    ,.SLOT1_DOUBLE(1)
`endif
) u_bank1(
    .rst         ( rst        ),
    .clk         ( clk        ),

    .slot0_addr  ( chr_addr  ),
    .slot0_dout  ( chr_data  ),
    .slot0_cs    ( chr_cs    ),
    .slot0_ok    ( chr_ok    ),

    .slot1_addr  ( chr2_addr  ),
    .slot1_dout  ( chr2_data  ),
    .slot1_cs    ( chr2_cs    ),
    .slot1_ok    ( chr2_ok    ),

    .sdram_ack   ( ba_ack[1]  ),
    .sdram_rd    ( ba_rd[1]   ),
    .sdram_addr  ( ba1_addr   ),
    .data_dst    ( ba_dst[1]  ),
    .data_rdy    ( ba_rdy[1]  ),
    .data_read   ( data_read  )
);
assign ba_wr[1] = 0;
assign ba1_din  = 0;
assign ba1_dsn  = 3;
jtframe_rom_2slots #(
    .SDRAMW(SDRAMW-1),

    .SLOT0_OKLATCH(0),
    .SLOT0_AW(19),
    .SLOT0_DW(16),

    .SLOT1_OFFSET(OBJ2_OFFSET[SDRAMW-2:0]),
    .SLOT1_OKLATCH(0),
    .SLOT1_AW(18),
    .SLOT1_DW(16)
`ifdef JTFRAME_BA2_LEN
    ,.SLOT0_DOUBLE(1)
    ,.SLOT1_DOUBLE(1)
`endif
) u_bank2(
    .rst         ( rst        ),
    .clk         ( clk        ),

    .slot0_addr  ( obj_addr  ),
    .slot0_dout  ( obj_data  ),
    .slot0_cs    ( obj_cs    ),
    .slot0_ok    ( obj_ok    ),

    .slot1_addr  ( obj2_addr  ),
    .slot1_dout  ( obj2_data  ),
    .slot1_cs    ( obj2_cs    ),
    .slot1_ok    ( obj2_ok    ),

    .sdram_ack   ( ba_ack[2]  ),
    .sdram_rd    ( ba_rd[2]   ),
    .sdram_addr  ( ba2_addr   ),
    .data_dst    ( ba_dst[2]  ),
    .data_rdy    ( ba_rdy[2]  ),
    .data_read   ( data_read  )
);
assign ba_wr[2] = 0;
assign ba2_din  = 0;
assign ba2_dsn  = 3;
jtframe_rom_2slots #(
    .SDRAMW(SDRAMW-1),

    .SLOT0_OKLATCH(0),
    .SLOT0_AW(18),
    .SLOT0_DW( 8),

    .SLOT1_OFFSET(PCMA_OFFSET[SDRAMW-2:0]),
    .SLOT1_OKLATCH(0),
    .SLOT1_AW(20),
    .SLOT1_DW( 8)
`ifdef JTFRAME_BA3_LEN
    ,.SLOT0_DOUBLE(1)
    ,.SLOT1_DOUBLE(1)
`endif
) u_bank3(
    .rst         ( rst        ),
    .clk         ( clk        ),

    .slot0_addr  ( pcmb_addr  ),
    .slot0_dout  ( pcmb_data  ),
    .slot0_cs    ( pcmb_cs    ),
    .slot0_ok    ( pcmb_ok    ),

    .slot1_addr  ( pcma_addr  ),
    .slot1_dout  ( pcma_data  ),
    .slot1_cs    ( pcma_cs    ),
    .slot1_ok    ( pcma_ok    ),

    .sdram_ack   ( ba_ack[3]  ),
    .sdram_rd    ( ba_rd[3]   ),
    .sdram_addr  ( ba3_addr   ),
    .data_dst    ( ba_dst[3]  ),
    .data_rdy    ( ba_rdy[3]  ),
    .data_read   ( data_read  )
);
assign ba_wr[3] = 0;
assign ba3_din  = 0;
assign ba3_dsn  = 3;
assign hold_rst=0;
`ifdef JTFRAME_PROM_START
localparam JTFRAME_PROM_START=`JTFRAME_PROM_START;
`endif

assign snd_vu   = 0;
assign snd_peak = 0;

endmodule
