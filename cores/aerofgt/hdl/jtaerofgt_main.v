`timescale 1ns/1ps

module jtaerofgt_main(
    input              rst,
    input              clk,

    input              dip_pause,
    input              vblank_irq,

    input       [ 5:0] joystick1,
    input       [ 5:0] joystick2,
    input       [ 3:0] cab_1p,
    input       [ 3:0] coin,
    input              service,
    input       [15:0] dipsw,

    output      [ 7:0] sndlatch_data,
    output              sndlatch_we,
    input               sndlatch_pending,

    output      [ 7:0] dbg_view,

    output             main_cs,
    output      [18:1] main_addr,
    input       [15:0] main_data,
    input              main_ok,

    input       [11:1] ram_vaddr,
    output      [15:0] ram_vq,
    input       [12:1] vram0_vaddr,
    output      [15:0] vram0_vq,
    input       [12:1] vram1_vaddr,
    output      [15:0] vram1_vq,
    input       [10:1] pal_vaddr,
    output      [15:0] pal_vq,
    input       [10:1] pal1_vaddr,
    output      [15:0] pal1_vq,
    input       [10:1] pal2_vaddr,
    output      [15:0] pal2_vq,

    input       [14:1] sprlook_vaddr,
    output      [15:0] sprlook_vq,
    input       [12:1] spr_vaddr,
    output      [15:0] spr_vq,

    output      [63:0] gfxbank_flat,
    output  reg [15:0] scrolly0,
    output  reg [15:0] scrolly1
);

wire [23:1] A;
wire [ 2:0] FC;
wire        ASn, RnW, DTACKn, VPAn, cpu_cen, cpu_cenb;
wire [ 1:0] dsn;
wire [15:0] cpu_dout, fave;
reg  [15:0] cpu_din;
reg         ok_dly;

reg         rom_cs, ram_cs, pal_cs, vram0_cs, vram1_cs,
            sprlook_cs, spr_cs, work_cs, io_cs,
            gfxbank_we, scry0_we, scry1_we, sndlatch_we_int;

wire [15:0] ram_q, pal_q, vram0_q, vram1_q, sprlook_q, spr_q, work_q;

wire [ 3:0] io_idx = Ab[4:1];

wire [ 7:0] p1_byte = { 2'b11, joystick1[5], joystick1[4], joystick1[0], joystick1[1],
                                joystick1[2], joystick1[3] };
wire [ 7:0] p2_byte = { 2'b11, joystick2[5], joystick2[4], joystick2[0], joystick2[1],
                                joystick2[2], joystick2[3] };
wire [ 7:0] system_byte = { 1'b1, service, 2'b11, cab_1p[1], cab_1p[0], coin[1], coin[0] };

wire [ 7:0] io_q =
    io_idx==4'd0 ? p1_byte      :
    io_idx==4'd1 ? p2_byte      :
    io_idx==4'd2 ? system_byte  :
    io_idx==4'd3 ? dipsw[7:0]   :
    io_idx==4'd4 ? dipsw[15:8]  :
    io_idx==4'd6 ? {7'd0, sndlatch_pending} :
    io_idx==4'd7 ? 8'h00        :
                   8'hff;

assign dbg_view = { ASn, DTACKn, RnW, rom_cs, ram_cs, vram0_cs, vram1_cs, work_cs };

reg  [15:0] gfxbank[0:3];
reg  [ 7:0] sndlatch;

assign gfxbank_flat   = {gfxbank[3], gfxbank[2], gfxbank[1], gfxbank[0]};
assign sndlatch_data  = sndlatch;
assign sndlatch_we    = sndlatch_we_int;

wire        wr      = !RnW;
wire [ 1:0] byte_we = { ~dsn[1] & wr, ~dsn[0] & wr };
wire [23:0] Ab       = {A,1'b0};

wire [15:1] work_addr = A[15:1] - 15'h7800;

assign main_cs   = rom_cs;
assign main_addr = A[18:1];
assign VPAn      = ~&FC | ASn;

always @* begin
    rom_cs      = 1'b0;
    ram_cs      = 1'b0;
    pal_cs      = 1'b0;
    vram0_cs    = 1'b0;
    vram1_cs    = 1'b0;
    sprlook_cs  = 1'b0;
    spr_cs      = 1'b0;
    work_cs     = 1'b0;
    io_cs       = 1'b0;
    gfxbank_we  = 1'b0;
    scry0_we    = 1'b0;
    scry1_we    = 1'b0;
    sndlatch_we_int = 1'b0;
    if( !ASn && (RnW || dsn!=2'b11) ) begin
             if( Ab[23:19]==5'd0                             ) rom_cs      = 1'b1;
        else if( Ab>=24'h1A0000 && Ab<=24'h1A07FF             ) pal_cs      = 1'b1;
        else if( Ab>=24'h1B0000 && Ab<=24'h1B0FFF             ) ram_cs      = 1'b1;
        else if( Ab>=24'h1B2000 && Ab<=24'h1B3FFF             ) vram0_cs    = 1'b1;
        else if( Ab>=24'h1B4000 && Ab<=24'h1B5FFF             ) vram1_cs    = 1'b1;
        else if( Ab>=24'h1C0000 && Ab<=24'h1C7FFF             ) sprlook_cs  = 1'b1;
        else if( Ab>=24'h1D0000 && Ab<=24'h1D1FFF             ) spr_cs      = 1'b1;
        else if( Ab>=24'hFEF000 && Ab<=24'hFFEFFF             ) work_cs     = 1'b1;
        else if( Ab>=24'hFFFF80 && Ab<=24'hFFFF87 && !RnW     ) gfxbank_we  = 1'b1;
        else if( Ab>=24'hFFFF88 && Ab<=24'hFFFF89 && !RnW     ) scry0_we    = 1'b1;
        else if( Ab>=24'hFFFF90 && Ab<=24'hFFFF91 && !RnW     ) scry1_we    = 1'b1;
        else if( Ab>=24'hFFFFA0 && Ab<=24'hFFFFBF              ) io_cs       = 1'b1;

        else if( Ab==24'hFFFFC0 && !RnW && !dsn[0]            ) sndlatch_we_int = 1'b1;
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scrolly0 <= 16'd0;
        scrolly1 <= 16'd0;
        sndlatch <= 8'd0;
    end else begin
        if( gfxbank_we  ) gfxbank[A[2:1]] <= cpu_dout;
        if( scry0_we    ) scrolly0        <= cpu_dout;
        if( scry1_we    ) scrolly1        <= cpu_dout;
        if( sndlatch_we_int ) sndlatch    <= cpu_dout[7:0];
    end
end

always @(posedge clk) begin
    ok_dly  <= main_ok;
    cpu_din <= rom_cs     ? main_data  :
               ram_cs     ? ram_q      :
               pal_cs     ? pal_q      :
               vram0_cs   ? vram0_q    :
               vram1_cs   ? vram1_q    :
               sprlook_cs ? sprlook_q  :
               spr_cs     ? spr_q      :
               work_cs    ? work_q     :
               io_cs      ? {8'hff, io_q} :
                            16'hffff;
end

jtframe_dual_ram16 #(.AW(11)) u_ram(
    .clk0  ( clk               ),
    .data0 ( cpu_dout          ),
    .addr0 ( A[11:1]           ),
    .we0   ( {2{ram_cs}} & byte_we ),
    .q0    ( ram_q             ),
    .clk1  ( clk               ),
    .data1 ( 16'd0             ),
    .addr1 ( ram_vaddr         ),
    .we1   ( 2'b00             ),
    .q1    ( ram_vq            )
);

jtframe_dual_ram16 #(.AW(10)) u_pal(
    .clk0  ( clk               ),
    .data0 ( cpu_dout          ),
    .addr0 ( A[10:1]           ),
    .we0   ( {2{pal_cs}} & byte_we ),
    .q0    ( pal_q             ),
    .clk1  ( clk               ),
    .data1 ( 16'd0             ),
    .addr1 ( pal_vaddr         ),
    .we1   ( 2'b00             ),
    .q1    ( pal_vq            )
);

jtframe_dual_ram16 #(.AW(10)) u_pal1(
    .clk0  ( clk               ),
    .data0 ( cpu_dout          ),
    .addr0 ( A[10:1]           ),
    .we0   ( {2{pal_cs}} & byte_we ),
    .q0    (                   ),
    .clk1  ( clk               ),
    .data1 ( 16'd0             ),
    .addr1 ( pal1_vaddr        ),
    .we1   ( 2'b00             ),
    .q1    ( pal1_vq           )
);

jtframe_dual_ram16 #(.AW(10)) u_pal2(
    .clk0  ( clk               ),
    .data0 ( cpu_dout          ),
    .addr0 ( A[10:1]           ),
    .we0   ( {2{pal_cs}} & byte_we ),
    .q0    (                   ),
    .clk1  ( clk               ),
    .data1 ( 16'd0             ),
    .addr1 ( pal2_vaddr        ),
    .we1   ( 2'b00             ),
    .q1    ( pal2_vq           )
);

jtframe_dual_ram16 #(.AW(12)) u_vram0(
    .clk0  ( clk               ),
    .data0 ( cpu_dout          ),
    .addr0 ( A[12:1]           ),
    .we0   ( {2{vram0_cs}} & byte_we ),
    .q0    ( vram0_q           ),
    .clk1  ( clk               ),
    .data1 ( 16'd0             ),
    .addr1 ( vram0_vaddr       ),
    .we1   ( 2'b00             ),
    .q1    ( vram0_vq          )
);

jtframe_dual_ram16 #(.AW(12)) u_vram1(
    .clk0  ( clk               ),
    .data0 ( cpu_dout          ),
    .addr0 ( A[12:1]           ),
    .we0   ( {2{vram1_cs}} & byte_we ),
    .q0    ( vram1_q           ),
    .clk1  ( clk               ),
    .data1 ( 16'd0             ),
    .addr1 ( vram1_vaddr       ),
    .we1   ( 2'b00             ),
    .q1    ( vram1_vq          )
);

jtframe_dual_ram16 #(.AW(14)) u_sprlook(
    .clk0  ( clk               ),
    .data0 ( cpu_dout          ),
    .addr0 ( A[14:1]           ),
    .we0   ( {2{sprlook_cs}} & byte_we ),
    .q0    ( sprlook_q         ),
    .clk1  ( clk               ),
    .data1 ( 16'd0             ),
    .addr1 ( sprlook_vaddr     ),
    .we1   ( 2'b00             ),
    .q1    ( sprlook_vq        )
);

jtframe_dual_ram16 #(.AW(12)) u_spr(
    .clk0  ( clk               ),
    .data0 ( cpu_dout          ),
    .addr0 ( A[12:1]           ),
    .we0   ( {2{spr_cs}} & byte_we ),
    .q0    ( spr_q             ),
    .clk1  ( clk               ),
    .data1 ( 16'd0             ),
    .addr1 ( spr_vaddr         ),
    .we1   ( 2'b00             ),
    .q1    ( spr_vq            )
);

jtframe_ram16 #(.AW(15)) u_work(
    .clk  ( clk               ),
    .data ( cpu_dout          ),
    .addr ( work_addr         ),
    .we   ( {2{work_cs}} & byte_we ),
    .q    ( work_q            )
);

wire bus_cs   = rom_cs;
wire bus_busy = rom_cs & ~ok_dly;

wire vb_int, vint_ack = &FC & ~ASn;
jtframe_edge u_vbint(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .edgeof     ( vblank_irq ),
    .clr        ( vint_ack   ),
    .q          ( vb_int     )
);
wire [2:0] IPLn = vb_int ? 3'b110 : 3'b111;

`ifdef SIMULATION
reg dbg_trace_pc;
initial dbg_trace_pc = $test$plusargs("trace_pc");
reg dbg_ASn_d, dbg_rst_d;
always @(posedge clk) dbg_ASn_d <= ASn;
always @(posedge clk) dbg_rst_d <= rst;
wire dbg_bus_start = dbg_ASn_d && !ASn;
wire dbg_bus_end   = !dbg_ASn_d && ASn;
always @(posedge clk) if (dbg_trace_pc && (dbg_bus_start || dbg_bus_end))
    $display("BUS %s addr=%06h RnW=%b FC=%o rom=%b ram=%b pal=%b vram0=%b vram1=%b sprlook=%b spr=%b work=%b io=%b DTACKn=%b",
        dbg_bus_start ? "START" : "END  ",
        Ab, RnW, FC, rom_cs, ram_cs, pal_cs, vram0_cs, vram1_cs, sprlook_cs, spr_cs, work_cs, io_cs, DTACKn);
reg [7:0] dbg_relcnt;
always @(posedge clk) if (rst) dbg_relcnt <= 8'd0;
always @(posedge clk) if (dbg_trace_pc && dbg_rst_d && !rst) begin
    dbg_relcnt <= dbg_relcnt + 8'd1;
    $display("RESET RELEASED #%0d", dbg_relcnt + 8'd1);
end

reg [15:0] dbg_period;
always @(posedge clk) dbg_period <= dbg_period + 16'd1;
always @(posedge clk) if (dbg_trace_pc && dbg_period=='0)
    $display("SAMPLE rst=%b ASn=%b RnW=%b addr=%06h DTACKn=%b cpu_cen=%b", rst, ASn, RnW, Ab, DTACKn, cpu_cen);

reg        dbg_win_on;
reg [17:0] dbg_win_cnt;
reg        dbg_win_seen;
reg [12:0] dbg_uaddr_d;
reg [ 7:0] dbg_uchanges;
always @(posedge clk) begin
    if (dbg_trace_pc && dbg_rst_d && !rst && !dbg_win_on && dbg_relcnt==8'd0) begin
        dbg_win_on   <= 1'b1;
        dbg_win_cnt  <= 18'd0;
        dbg_win_seen <= 1'b0;
        dbg_uaddr_d  <= 13'h1fff;
        dbg_uchanges <= 8'd0;
    end else if (dbg_win_on) begin
        dbg_uaddr_d <= u_cpu.u_cpu.microAddr;
        if (!ASn && !dbg_win_seen) begin
            $display("CYC %0d FIRST BUS CYCLE addr=%06h RnW=%b bus_cs=%b", dbg_win_cnt, Ab, RnW, bus_cs);
            dbg_win_seen <= 1'b1;
            dbg_win_on   <= 1'b0;
        end else if (u_cpu.u_cpu.microAddr != dbg_uaddr_d && dbg_uchanges < 8'd200) begin
            $display("CYC %0d uCHANGE #%0d microAddr=%0h nanoAddr=%0h tState=%0d a0Rst=%b",
                dbg_win_cnt, dbg_uchanges, u_cpu.u_cpu.microAddr, u_cpu.u_cpu.nanoAddr,
                u_cpu.u_cpu.tState, u_cpu.u_cpu.sequencer.a0Rst);
            dbg_uchanges <= dbg_uchanges + 8'd1;
        end
        dbg_win_cnt <= dbg_win_cnt + 18'd1;
        if (dbg_win_cnt == 18'd199999) begin
            dbg_win_on <= 1'b0;
            $display("CYC %0d TIMEOUT -- nunca broke ASn en 200000 clk", dbg_win_cnt);
        end
    end
end

reg dbg_trace_paint;
initial dbg_trace_paint = $test$plusargs("trace_paint");
reg [15:0] dbg_paint_frame;
reg        dbg_vbirq_d;
always @(posedge clk) dbg_vbirq_d <= vblank_irq;
always @(posedge clk) if (rst) dbg_paint_frame <= 16'd0;
    else if (dbg_trace_paint && vblank_irq && !dbg_vbirq_d) dbg_paint_frame <= dbg_paint_frame + 16'd1;
always @(posedge clk) if (dbg_trace_paint && dbg_bus_start && !ASn && FC==3'b110) begin
    case (Ab)
        24'h00045a: $display("PAINT frame=%0d PC=00045a (arranque tras reset, vector)", dbg_paint_frame);
        24'h000496: $display("PAINT frame=%0d PC=000496 (dispatcher tests RAM)", dbg_paint_frame);
        24'h0004da: $display("PAINT frame=%0d PC=0004da (checksum ROM arranca)", dbg_paint_frame);
        24'h0004fe: $display("PAINT frame=%0d PC=0004fe (checksum ROM termina)", dbg_paint_frame);
        24'h00051e: $display("PAINT frame=%0d PC=00051e (diagnostico completo)", dbg_paint_frame);
        24'h000598: $display("PAINT frame=%0d PC=000598 (justo antes de escribir texto en VRAM1)", dbg_paint_frame);
        24'h0005da: $display("PAINT frame=%0d PC=0005da (arranca espera final)", dbg_paint_frame);
        24'h0005ec: $display("PAINT frame=%0d PC=0005ec (SALE del diagnostico)", dbg_paint_frame);
        24'h00083c: $display("PAINT frame=%0d PC=00083c (entra en el juego real)", dbg_paint_frame);
        default: ;
    endcase
end

reg dbg_rst_paint_d;
always @(posedge clk) dbg_rst_paint_d <= rst;
always @(posedge clk) if (dbg_trace_paint && rst && !dbg_rst_paint_d)
    $display("PAINT RST-ASSERT frame_previo=%0d", dbg_paint_frame);
always @(posedge clk) if (dbg_trace_paint && !rst && dbg_rst_paint_d)
    $display("PAINT RST-DEASSERT");
`endif

jtframe_68kdtack_cen #(.W(8)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ( dsn       ),
    .num        ( 7'd5      ),
    .den        ( 8'd24     ),
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .fave       ( fave      ),
    .fworst     (           )
);

jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .RESETn     (             ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),

    .eab        ( A           ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout    ),

    .eRWn       ( RnW         ),
    .LDSn       ( dsn[0]      ),
    .UDSn       ( dsn[1]      ),
    .ASn        ( ASn         ),
    .VPAn       ( VPAn        ),
    .FC         ( FC          ),

    .BERRn      ( 1'b1        ),

    .HALTn      ( dip_pause   ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),

    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        )
);

`ifdef SIMULATION
reg [15:0] sim_pal   [0:1023];
reg [15:0] sim_ras   [0:1023];
reg [15:0] sim_vram0 [0:4095];
reg [15:0] sim_vram1 [0:4095];
reg [15:0] sim_sprlk [0:16383];
reg [15:0] sim_spr   [0:4095];

`ifndef DUMP_FRAME
`define DUMP_FRAME 0
`endif

integer    dbg_dump_frame, dbg_frame_cnt, dbg_i, dbg_fd, dbg_plus;
reg        dbg_dumped;

initial begin
    for( dbg_i=0; dbg_i<1024;  dbg_i=dbg_i+1 ) begin sim_pal[dbg_i]=16'd0; sim_ras[dbg_i]=16'd0; end
    for( dbg_i=0; dbg_i<4096;  dbg_i=dbg_i+1 ) begin sim_vram0[dbg_i]=16'd0; sim_vram1[dbg_i]=16'd0; sim_spr[dbg_i]=16'd0; end
    for( dbg_i=0; dbg_i<16384; dbg_i=dbg_i+1 ) sim_sprlk[dbg_i]=16'd0;
    dbg_frame_cnt  = 0;
    dbg_dumped     = 1'b0;
    dbg_dump_frame = `DUMP_FRAME;
    if( $value$plusargs("dump_frame=%d", dbg_plus) ) dbg_dump_frame = dbg_plus;
    if( dbg_dump_frame!=0 )
        $display("DUMP armado: se volcara core_dump.hex en el frame %0d", dbg_dump_frame);
end

`define SIM_SNOOP(mem, idx) \
    if( byte_we[1] ) mem[idx][15:8] <= cpu_dout[15:8]; \
    if( byte_we[0] ) mem[idx][ 7:0] <= cpu_dout[ 7:0];

always @(posedge clk) begin
    if( pal_cs               ) begin `SIM_SNOOP(sim_pal,   A[10:1]) end
    if( ram_cs     && !A[11] ) begin `SIM_SNOOP(sim_ras,   A[10:1]) end
    if( vram0_cs             ) begin `SIM_SNOOP(sim_vram0, A[12:1]) end
    if( vram1_cs             ) begin `SIM_SNOOP(sim_vram1, A[12:1]) end
    if( sprlook_cs           ) begin `SIM_SNOOP(sim_sprlk, A[14:1]) end
    if( spr_cs               ) begin `SIM_SNOOP(sim_spr,   A[12:1]) end
end

reg dbg_vbl_d;
always @(posedge clk) dbg_vbl_d <= vblank_irq;
wire dbg_vbl_edge = vblank_irq && !dbg_vbl_d;

always @(posedge clk) begin
    if( rst ) begin
        dbg_frame_cnt <= 0;
        dbg_dumped    <= 1'b0;
    end else if( dbg_vbl_edge ) begin
        dbg_frame_cnt <= dbg_frame_cnt + 1;
        if( dbg_dump_frame!=0 && dbg_frame_cnt+1>=dbg_dump_frame && !dbg_dumped ) begin
            dbg_dumped <= 1'b1;
            dbg_fd = $fopen("core_dump.hex", "w");
            if( dbg_fd==0 ) begin
                $display("!! +dump_frame: no puedo abrir core_dump.hex");
            end else begin

                $fwrite(dbg_fd, "# palette base=1a0000 len_bytes=2048\n");
                for( dbg_i=0; dbg_i<1024;  dbg_i=dbg_i+1 ) $fwrite(dbg_fd, "%04x\n", sim_pal[dbg_i]);
                $fwrite(dbg_fd, "# rasterram base=1b0000 len_bytes=2048\n");
                for( dbg_i=0; dbg_i<1024;  dbg_i=dbg_i+1 ) $fwrite(dbg_fd, "%04x\n", sim_ras[dbg_i]);
                $fwrite(dbg_fd, "# vram0 base=1b2000 len_bytes=8192\n");
                for( dbg_i=0; dbg_i<4096;  dbg_i=dbg_i+1 ) $fwrite(dbg_fd, "%04x\n", sim_vram0[dbg_i]);
                $fwrite(dbg_fd, "# vram1 base=1b4000 len_bytes=8192\n");
                for( dbg_i=0; dbg_i<4096;  dbg_i=dbg_i+1 ) $fwrite(dbg_fd, "%04x\n", sim_vram1[dbg_i]);
                $fwrite(dbg_fd, "# sprlookupram base=1c0000 len_bytes=32768\n");
                for( dbg_i=0; dbg_i<16384; dbg_i=dbg_i+1 ) $fwrite(dbg_fd, "%04x\n", sim_sprlk[dbg_i]);
                $fwrite(dbg_fd, "# spriteram base=1d0000 len_bytes=8192\n");
                for( dbg_i=0; dbg_i<4096;  dbg_i=dbg_i+1 ) $fwrite(dbg_fd, "%04x\n", sim_spr[dbg_i]);
                $fwrite(dbg_fd, "# bank0=%04x\n", gfxbank[0]);
                $fwrite(dbg_fd, "# bank1=%04x\n", gfxbank[1]);
                $fwrite(dbg_fd, "# bank2=%04x\n", gfxbank[2]);
                $fwrite(dbg_fd, "# bank3=%04x\n", gfxbank[3]);
                $fwrite(dbg_fd, "# scrolly0=%04x\n", scrolly0);
                $fwrite(dbg_fd, "# scrolly1=%04x\n", scrolly1);
                $fclose(dbg_fd);

                $display("DUMP core_dump.hex escrito en el frame %0d", dbg_frame_cnt+1);
            end
        end
    end
end
`undef SIM_SNOOP
`endif

endmodule
