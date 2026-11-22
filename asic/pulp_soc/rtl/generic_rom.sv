// generic_rom.sv - boot ROM = OpenRAM ROM macro rom_2048x32 (asic/ROM)
// -----------------------------------------------------------------------------
// Replaces the standard-cell boot ROM that scripts/gen_boot_rom.py generated.
// Do NOT run gen_boot_rom.py: it would overwrite this file.
// -----------------------------------------------------------------------------
// Drop-in replacement for the PULP generic_rom used by boot_rom.sv (same module
// name, ports and timing):
//   CEN active low; address taken at the CLK rise; Q = ROM[address] from the
//   next cycle on (1-cycle latency, TCDM r_valid timing); Q holds the last
//   read word while there is no request.
//
// How it maps onto the macro:
//   CLK rise  : macro samples addr0 / cs0 (= ~CEN)
//   CLK high  : macro evaluates, dout0 valid ~7 ns after the rise
//   CLK fall  : dout0 captured into q_q (the macro output is only valid while
//               CLK is high) -> Q is stable for the whole next cycle
// => CLK high phase must be >= the macro access time (.lib min_pulse_width,
//    7.8 ns at TT) : SoC clock period >= 15.6 ns.
//
// FILE_NAME is the content the model loads. It must be the same content as the
// silicon (rom_2048x32.cde = sim/boot/boot_code.cde, md5 dfea2697...).
// -----------------------------------------------------------------------------

module generic_rom #(
  parameter ADDR_WIDTH = 11,
  parameter DATA_WIDTH = 32,
  parameter FILE_NAME  = "./boot/boot_code.cde"
) (
  input  logic                  CLK,
  input  logic                  CEN,
  input  logic [ADDR_WIDTH-1:0] A,
  output logic [DATA_WIDTH-1:0] Q
);

// pragma translate_off
`ifndef SYNTHESIS
  initial begin
    if (ADDR_WIDTH != 11 || DATA_WIDTH != 32)
      $fatal(1, "generic_rom (macro): rom_2048x32 needs ADDR_WIDTH=11 DATA_WIDTH=32, got %0d/%0d",
             ADDR_WIDTH, DATA_WIDTH);
  end
`endif
// pragma translate_on

  logic [DATA_WIDTH-1:0] rom_dout;
  logic                  req_q;
  logic [DATA_WIDTH-1:0] q_q;

  rom_2048x32 #(
`ifndef SYNTHESIS
    .MEM_FILE (FILE_NAME)
`endif
  ) u_rom_macro (
    .clk0  (CLK),
    .cs0   (~CEN),
    .addr0 (A),
    .dout0 (rom_dout)
  );

  // remember whether this cycle was a read
  always_ff @(posedge CLK)
    req_q <= ~CEN;

  // capture the macro output at the falling edge (end of the evaluate phase)
  always_ff @(negedge CLK)
    if (req_q)
      q_q <= rom_dout;

  assign Q = q_q;

endmodule
