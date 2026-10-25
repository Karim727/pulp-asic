// Lint-only black-box stubs for pulp_soc (no synthesis, no P&R).
// Sources: soc_clk_rst_gen.sv:76,99,121 (gf22_FLL),
// memory_models.sv:121-296 (generic_memory), boot_rom.sv:43 (generic_rom).
(* blackbox *)
module gf22_FLL (
  output logic        FLLCLK,
  input  logic        FLLOE,
  input  logic        REFCLK,
  output logic        LOCK,
  input  logic        CFGREQ,
  output logic        CFGACK,
  input  logic [1:0]  CFGAD,
  input  logic [31:0] CFGD,
  output logic [31:0] CFGQ,
  input  logic        CFGWEB,
  input  logic        RSTB,
  input  logic        PWD,
  input  logic        RET,
  input  logic        TM,
  input  logic        TE,
  input  logic        TD,  // TODO: width inferred from 1'b0 tie-off, no vendor model
  output logic        TQ,  // TODO: width inferred from empty () tie-off, no vendor model
  input  logic        JTD, // TODO: width inferred from 1'b0 tie-off, no vendor model
  output logic        JTQ  // TODO: width inferred from empty () tie-off, no vendor model
);
  assign FLLCLK = '0;
  assign LOCK   = '0;
  assign CFGACK = '0;
  assign CFGQ   = '0;
  assign TQ     = '0;
  assign JTQ    = '0;
endmodule
(* blackbox *)
module generic_memory #(
  parameter ADDR_WIDTH = 12,
  parameter DATA_WIDTH = 32,
  parameter BE_WIDTH   = DATA_WIDTH/8
)(
  input  logic                  CLK,
  input  logic                  INITN,
  input  logic                  CEN,
  input  logic [ADDR_WIDTH-1:0] A,
  input  logic                  WEN,
  input  logic [DATA_WIDTH-1:0] D,
  input  logic [BE_WIDTH-1:0]   BEN,
  output logic [DATA_WIDTH-1:0] Q
);
  assign Q = '0;
endmodule
/*(* blackbox *)
module generic_rom #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32
)(
  input  logic                  CLK,
  input  logic                  CEN,
  input  logic [ADDR_WIDTH-1:0] A,
  output logic [DATA_WIDTH-1:0] Q
);
  assign Q = '0;
endmodule*/
