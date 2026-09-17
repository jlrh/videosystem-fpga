`timescale 1ns/1ps

module jtaerofgt_video_timing(
    input             rst,
    input             clk,

    output            pxl_cen,

    output            pxl2_cen,

    output reg [8:0]  hcnt,
    output reg [8:0]  vcnt,
    output            HS,
    output            VS,
    output            LHBL,
    output            LVBL,
    output reg        vblank_irq
);

localparam HVIS = 320, HFP = 80, HSW = 24, HBP = 32;
localparam VVIS = 224, VFP = 20, VSW =  4, VBP =  8;
localparam HTOTAL = HVIS+HFP+HSW+HBP, VTOTAL = VVIS+VFP+VSW+VBP;
localparam SYNC_ACTIVE = 1'b1;

jtframe_frac_cen #(.W(2),.WC(10)) u_pxlcen(
    .clk    ( clk               ),
    .n      ( 10'd105           ),
    .m      ( 10'd352           ),
    .cen    ( { pxl_cen, pxl2_cen } ),
    .cenb   (                   )
);

wire hmax = hcnt == HTOTAL-1;
wire vmax = vcnt == VTOTAL-1;

`ifdef SIMULATION
initial begin
    hcnt = 9'd0;
    vcnt = 9'd0;
    vblank_irq = 1'b0;
end
`endif

always @(posedge clk) begin
    if( pxl_cen ) begin
        vblank_irq <= 1'b0;
        if( hmax ) begin
            hcnt <= 9'd0;
            vcnt <= vmax ? 9'd0 : vcnt+9'd1;
            if( vcnt == VVIS-1 ) vblank_irq <= 1'b1;
        end else begin
            hcnt <= hcnt+9'd1;
        end
    end
end

assign LHBL = hcnt < HVIS;
assign LVBL = vcnt < VVIS;
assign HS   = (hcnt >= HVIS+HFP && hcnt < HVIS+HFP+HSW) ? SYNC_ACTIVE : ~SYNC_ACTIVE;
assign VS   = (vcnt >= VVIS+VFP && vcnt < VVIS+VFP+VSW) ? SYNC_ACTIVE : ~SYNC_ACTIVE;

endmodule
