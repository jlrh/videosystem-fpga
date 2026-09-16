`timescale 1ns/1ps

module jtaerofgt_sound(
    input               rst,
    input               clk,

    input       [ 7:0]  sndlatch_data,
    input               sndlatch_we,
    output              sndlatch_pending,

    output              snd_cs,
    output      [16:0]  snd_addr,
    input       [ 7:0]  snd_data,
    input                snd_ok,

    output              pcma_cs,
    output      [19:0]  pcma_addr,
    input       [ 7:0]  pcma_data,

    output              pcmb_cs,
    output      [17:0]  pcmb_addr,
    input       [ 7:0]  pcmb_data,

    output  signed [15:0] snd,

    output              sample,

    output      [ 7:0]  dbg_view
);
assign dbg_view = { m1_n, mreq_n, iorq_n, wr_n, nmi_n, int_n, fm_cs, sndlatch_pending };

wire [1:0] cen_snd2, cen_fm2;
wire cen_snd = cen_snd2[0];
wire cen_fm  = cen_fm2[0];
jtframe_frac_cen #(.W(2)) u_cen_snd(
    .clk    ( clk       ),
    .n      ( 10'd5     ),
    .m      ( 10'd48    ),
    .cen    ( cen_snd2  ),
    .cenb   (           )
);
jtframe_frac_cen #(.W(2)) u_cen_fm(
    .clk    ( clk       ),
    .n      ( 10'd8     ),
    .m      ( 10'd48    ),
    .cen    ( cen_fm2   ),
    .cenb   (           )
);

wire        rst_n = ~rst;
wire        cpu_cen, m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, halt_n, busak_n;
wire [15:0] A;
wire [ 7:0] cpu_dout, ram_dout;
reg  [ 7:0] cpu_din;
wire        rom_cs, ram_cs;
wire        int_n;

wire mem_acc = ~mreq_n & rfsh_n;

assign ram_cs = mem_acc &&  A[15:11]==5'b01111;
assign rom_cs = mem_acc && !(A[15:11]==5'b01111);

jtframe_sysz80 #(.RAM_AW(11)) u_cpu(
    .rst_n      ( rst_n     ),
    .clk        ( clk       ),
    .cen        ( cen_snd   ),
    .cpu_cen    ( cpu_cen   ),
    .int_n      ( int_n     ),
    .nmi_n      ( nmi_n     ),
    .busrq_n    ( 1'b1      ),
    .m1_n       ( m1_n      ),
    .mreq_n     ( mreq_n    ),
    .iorq_n     ( iorq_n    ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .rfsh_n     ( rfsh_n    ),
    .halt_n     ( halt_n    ),
    .busak_n    ( busak_n   ),
    .A          ( A         ),
    .cpu_din    ( cpu_din   ),
    .cpu_dout   ( cpu_dout  ),
    .ram_dout   ( ram_dout  ),
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( snd_ok    )
);

assign snd_cs   = rom_cs;
assign snd_addr = { A[15] ? bank : 2'b00, A[14:0] };

reg [1:0] bank;

wire io_rw     = !iorq_n && m1_n;
wire fm_cs     = io_rw && A[7:2]==6'd0;
wire bank_cs   = io_rw && A[7:0]==8'h04;
wire ack_cs    = io_rw && A[7:0]==8'h08;
wire latchr_cs = io_rw && A[7:0]==8'h0c;

always @(posedge clk, posedge rst) begin
    if( rst ) bank <= 2'd0;
    else if( bank_cs && !wr_n ) bank <= cpu_dout[1:0];
end

reg pending;
always @(posedge clk, posedge rst) begin
    if( rst ) pending <= 1'b0;
    else if( sndlatch_we ) pending <= 1'b1;
    else if( ack_cs && !wr_n ) pending <= 1'b0;
end
assign sndlatch_pending = pending;
wire nmi_n = ~pending;

wire [7:0] jt10_dout;
always @(posedge clk) begin
    cpu_din <= rom_cs      ? snd_data  :
               ram_cs      ? ram_dout  :
               fm_cs       ? jt10_dout :
               latchr_cs   ? sndlatch_data :
                              8'hff;
end

wire [19:0] adpcma_addr;
wire [ 3:0] adpcma_bank;
wire        adpcma_roe_n;
wire [23:0] adpcmb_addr;
wire        adpcmb_roe_n;
wire signed [15:0] jt10_l, jt10_r;

assign pcma_cs   = ~adpcma_roe_n;
assign pcma_addr = adpcma_addr;
assign pcmb_cs   = ~adpcmb_roe_n;
assign pcmb_addr = adpcmb_addr[17:0];

jt10 u_fm(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen            ( cen_fm        ),
    .din            ( cpu_dout      ),
    .addr           ( A[1:0]        ),
    .cs_n           ( ~fm_cs        ),
    .wr_n           ( wr_n          ),

    .dout           ( jt10_dout     ),
    .irq_n          ( int_n         ),

    .adpcma_addr    ( adpcma_addr   ),
    .adpcma_bank    ( adpcma_bank   ),
    .adpcma_roe_n   ( adpcma_roe_n  ),
    .adpcma_data    ( pcma_data     ),
    .adpcmb_addr    ( adpcmb_addr   ),
    .adpcmb_roe_n   ( adpcmb_roe_n  ),
    .adpcmb_data    ( pcmb_data     ),

    .psg_A          (               ),
    .psg_B          (               ),
    .psg_C          (               ),
    .fm_snd         (               ),
    .psg_snd        (               ),
    .snd_right      ( jt10_r        ),
    .snd_left       ( jt10_l        ),
    .snd_sample     ( sample        ),
    .ch_enable      ( 6'b11_1111    )
);

wire signed [15:0] snd_mix = (jt10_l>>>1) + (jt10_r>>>1);

jtframe_dcrm #(.SW(16),.SIGNED_INPUT(1)) u_dcrm(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .sample ( sample    ),
    .din    ( snd_mix   ),
    .dout   ( snd       )
);

endmodule
