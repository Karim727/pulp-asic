// gf22_FLL.sv
// -----------------------------------------------------------------------------
// SKY130 replacement for the GF22 FLL (pulp_soc ASIC flow).
//
// The real gf22_FLL is a GF22 mixed-signal block with no SKY130 equivalent.
// This module keeps the same ports so soc_clk_rst_gen.sv needs no change,
// but it is just a wire for the clock:
//
//   FLLCLK = REFCLK   -> soc, peripheral and cluster clocks all come from ref_clk_i
//                        (the clock muxes see ref_clk_i on both inputs, so the
//                         JTAG sel_fll_clk setting does not matter)
//   LOCK   = 1        -> "always locked", software never waits for lock
//   CFGACK = CFGREQ   -> FLL config accesses from apb_fll_if always complete
//                        (apb_fll_if syncs ack with 2 flops -> no comb loop)
//   CFGQ   = 0        -> FLL registers read as 0
//
// Used 3 times in soc_clk_rst_gen.sv: i_fll_soc, i_fll_per, i_fll_cluster.
// Later the ring oscillator can drive ref_clk_i from chip top level.
// -----------------------------------------------------------------------------

module gf22_FLL (
  output logic        FLLCLK,   // FLL output clock
  input  logic        FLLOE,    // FLL output enable       (unused)
  input  logic        REFCLK,   // reference clock
  output logic        LOCK,     // FLL locked
  input  logic        CFGREQ,   // config request
  output logic        CFGACK,   // config acknowledge
  input  logic [1:0]  CFGAD,    // config address         (unused)
  input  logic [31:0] CFGD,     // config write data      (unused)
  output logic [31:0] CFGQ,     // config read data
  input  logic        CFGWEB,   // config write enable    (unused)
  input  logic        RSTB,     // reset                  (unused)
  input  logic        PWD,      // power down             (unused)
  input  logic        RET,      // retention              (unused)
  input  logic        TM,       // test mode              (unused)
  input  logic        TE,       // test enable            (unused)
  input  logic        TD,       // test data in           (unused)
  output logic        TQ,       // test data out
  input  logic        JTD,      // JTAG test data in      (unused)
  output logic        JTQ       // JTAG test data out
);

  assign FLLCLK = REFCLK;
  assign LOCK   = 1'b1;
  assign CFGACK = CFGREQ;
  assign CFGQ   = '0;
  assign TQ     = 1'b0;
  assign JTQ    = 1'b0;

endmodule
