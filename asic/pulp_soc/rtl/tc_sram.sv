// Blackbox stub for tc_sram (tech_cells_generic), replacing the full behavioral
// model so the L2 SRAM is treated as a macro by synthesis instead of being
// elaborated into a 4 Mbit flop-per-bit array.
//
// IMPORTANT: cannot keep the original full body here with (* blackbox *) —
// the original declares `parameter type addr_t/data_t/be_t` and slang
// (read_slang) rejects type parameters inside blackbox modules
// ("blackbox cannot have a type parameter"). Port widths are therefore
// written directly with AddrWidth/DataWidth/BeWidth instead of addr_t/data_t/be_t.
//
// Used by: l2_ram_multi_bank.sv (L2 interleaved + priority banks)
(* blackbox *)
module tc_sram #(
  parameter int unsigned NumWords     = 32'd1024, // Number of Words in data array
  parameter int unsigned DataWidth    = 32'd128,  // Data signal width
  parameter int unsigned ByteWidth    = 32'd8,    // Width of a data byte
  parameter int unsigned NumPorts     = 32'd2,    // Number of read and write ports
  parameter int unsigned Latency      = 32'd1,    // Latency when the read data is available
  parameter              SimInit      = "none",   // Simulation initialization (unused in stub)
  parameter bit          PrintSimCfg  = 1'b0,     // Print configuration (unused in stub)
  // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
  parameter int unsigned AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1,
  parameter int unsigned BeWidth   = (DataWidth + ByteWidth - 32'd1) / ByteWidth // ceil_div
) (
  input  logic                                 clk_i,    // Clock
  input  logic                                 rst_ni,   // Asynchronous reset active low
  // input ports
  input  logic [NumPorts-1:0]                  req_i,    // request
  input  logic [NumPorts-1:0]                  we_i,     // write enable
  input  logic [NumPorts-1:0][AddrWidth-1:0]   addr_i,   // request address
  input  logic [NumPorts-1:0][DataWidth-1:0]   wdata_i,  // write data
  input  logic [NumPorts-1:0][BeWidth-1:0]     be_i,     // write byte enable
  // output ports
  output logic [NumPorts-1:0][DataWidth-1:0]   rdata_o   // read data
);
endmodule
