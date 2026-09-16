`ifdef JTFRAME_SRAM
    output    [16:0]  sram_addr,
    output    [15:0]  sram_din,
    input     [15:0]  sram_dout,
    output            sram_wen,
    output    [ 1:0]  sram_dsn,
    input             sram_ok,
`endif
    // Audio channels
    
    // Sound output
`ifndef JTFRAME_STEREO
    output  signed [15:0] snd,
`else
    output  signed [15:0] snd_left, snd_right,
`endif
    output          sample,

    // Memory ports
`ifdef JTFRAME_SDRAM_LARGE
    input   [22:0]  prog_addr,
`else
    input   [21:0]  prog_addr,
`endif
    input   [ 7:0]  prog_data,
    input           prog_we,
    input   [ 1:0]  prog_ba,
    input   [25:0]  ioctl_addr,
    input           prom_we,
`ifdef JTFRAME_HEADER
    input           header,
`endif
`ifdef JTFRAME_IOCTL_RD
    input           ioctl_wr,
    output   [ 7:0] ioctl_din,
    input    [ 7:0] ioctl_dout, `endif
    input           ioctl_ram,
    input           ioctl_cart,
    // Explicit ports
    // Buses to BRAM

    // Buses to SDRAM
    input    [15:0] main_data,
    output          main_cs,
    output   [18:1] main_addr,
    input           main_ok,

    input    [ 7:0] snd_data,
    output          snd_cs,
    output   [16:0] snd_addr,
    input           snd_ok,

    input    [15:0] chr_data,
    output          chr_cs,
    output   [19:1] chr_addr,
    input           chr_ok,

    input    [15:0] chr2_data,
    output          chr2_cs,
    output   [19:1] chr2_addr,
    input           chr2_ok,

    input    [15:0] obj_data,
    output          obj_cs,
    output   [19:1] obj_addr,
    input           obj_ok,

    input    [15:0] obj2_data,
    output          obj2_cs,
    output   [18:1] obj2_addr,
    input           obj2_ok,

    input    [ 7:0] pcmb_data,
    output          pcmb_cs,
    output   [17:0] pcmb_addr,
    input           pcmb_ok,

    input    [ 7:0] pcma_data,
    output          pcma_cs,
    output   [19:0] pcma_addr,
    input           pcma_ok
