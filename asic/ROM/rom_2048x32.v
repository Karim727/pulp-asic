// rom_2048x32 - behavioral model of the OpenRAM boot ROM macro (SKY130)
//
// 2048 words x 32 bits, content = rom_2048x32.cde (the boot code, one 32-digit
// binary word per line, first digit = dout0[31]). The layout was checked to
// store exactly this content in this bit order.
//
// Timing (same as rom_2048x32_TT_1p8V_25C.lib):
//   clk0 low  : precharge
//   clk0 rise : addr0 / cs0 are sampled (setup to the rise)
//   clk0 high : dout0 becomes valid DELAY after the rise
//   clk0 fall : dout0 must be captured here; after the fall the real macro
//               output is not valid (precharge) -> the model drives X after
//               T_HOLD, so a wrong capture edge shows up in simulation.
//   Define ROM_MODEL_NO_X to keep dout0 stable instead.
//
// Replaces the OpenRAM-generated model, which read the binary .bin file with
// $readmemb and changed dout0 after the clk0 fall (did not match the macro).

`timescale 1ns/1ps

// +define+ROM_MODEL_DELAY=<ns> overrides the access time (e.g. for a fast sim clock)
`ifndef ROM_MODEL_DELAY
`define ROM_MODEL_DELAY 7.0
`endif

module rom_2048x32 #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 11,
  parameter ROM_DEPTH  = 1 << ADDR_WIDTH,
  parameter MEM_FILE   = "rom_2048x32.cde",
  parameter real DELAY  = `ROM_MODEL_DELAY,  // clk0 rise -> dout0 (.lib TT, worst case)
  parameter real T_HOLD = 0.1    // dout0 kept after the clk0 fall
)(
`ifdef USE_POWER_PINS
  inout                       vccd1,
  inout                       vssd1,
`endif
  input                       clk0,   // clock
  input                       cs0,    // chip select, active high
  input      [ADDR_WIDTH-1:0] addr0,
  output reg [DATA_WIDTH-1:0] dout0
);

  reg [DATA_WIDTH-1:0] mem [0:ROM_DEPTH-1];

  // simulation only: synthesis / LibreLane read this file as a black box
  // (yosys would try to open MEM_FILE while parsing)
`ifndef SYNTHESIS
  initial begin
    $readmemb(MEM_FILE, mem);
    dout0 = {DATA_WIDTH{1'bx}};
  end
`endif

  // evaluate: sample address at the rise, data valid DELAY later
  always @(posedge clk0) begin
    if (cs0)
      dout0 <= #(DELAY) mem[addr0];
    else
      dout0 <= #(DELAY) {DATA_WIDTH{1'bx}};
  end

`ifndef ROM_MODEL_NO_X
  // precharge: output not valid after the fall
  always @(negedge clk0)
    dout0 <= #(T_HOLD) {DATA_WIDTH{1'bx}};
`endif

endmodule
