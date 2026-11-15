// tc_sram_l2.sv
// -----------------------------------------------------------------------------
// L2 memory cut for the pulp_soc ASIC flow (SKY130).
// Drop-in replacement for tech_cells_generic tc_sram, used by
// asic/pulp_soc/rtl/l2_ram_multi_bank.sv for every L2 bank.
//
// Built from N x sram_32x1024 OpenRAM macros (1024 words x 32 bit, 1RW).
//   N = NumWords / 1024   (computed automatically)
//   e.g. private bank     : NumWords = 4096 -> 4 macros (16 KB)
//        interleaved bank : NumWords = 2048 -> 2 macros ( 8 KB)
// The upper address bits select the macro, the lower 10 bits go to the
// macro address port. Only the selected macro is enabled (csb0 low).
//
// Views:
//   TARGET_SYNTHESIS defined (LibreLane config.yaml VERILOG_DEFINES)
//       -> macro view: instantiates sram_32x1024 hard macros.
//   otherwise (RTL simulation)
//       -> behavioral view: plain memory array, same 1-cycle read latency.
//
// Port widths are declared directly (no type parameters) so slang can read it.
// Supported configuration: DataWidth = 32, ByteWidth = 8, NumPorts = 1,
// NumWords = k * 1024.
// -----------------------------------------------------------------------------

module tc_sram_l2 #(
  parameter int unsigned NumWords     = 32'd1024, // Number of words in data array
  parameter int unsigned DataWidth    = 32'd32,   // Data signal width
  parameter int unsigned ByteWidth    = 32'd8,    // Width of a data byte
  parameter int unsigned NumPorts     = 32'd1,    // Number of read and write ports
  parameter int unsigned Latency      = 32'd1,    // Read latency (macro is fixed at 1)
  parameter              SimInit      = "none",   // Unused, kept for tc_sram compatibility
  parameter bit          PrintSimCfg  = 1'b0,     // Unused, kept for tc_sram compatibility
  // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
  parameter int unsigned AddrWidth    = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1,
  parameter int unsigned BeWidth      = (DataWidth + ByteWidth - 32'd1) / ByteWidth
) (
  input  logic                                 clk_i,
  input  logic                                 rst_ni,
  input  logic  [NumPorts-1:0]                 req_i,
  input  logic  [NumPorts-1:0]                 we_i,
  input  logic  [NumPorts-1:0][AddrWidth-1:0]  addr_i,
  input  logic  [NumPorts-1:0][DataWidth-1:0]  wdata_i,
  input  logic  [NumPorts-1:0][BeWidth-1:0]    be_i,
  output logic  [NumPorts-1:0][DataWidth-1:0]  rdata_o
);

  // ---------------------------------------------------------------------------
  // Configuration check (simulation only)
  // ---------------------------------------------------------------------------
// pragma translate_off
`ifndef SYNTHESIS
  initial begin
    if (DataWidth != 32 || ByteWidth != 8 || NumPorts != 1 ||
        NumWords < 1024 || (NumWords % 1024) != 0) begin
      $fatal(1, "tc_sram_l2: unsupported config NumWords=%0d DataWidth=%0d ByteWidth=%0d NumPorts=%0d (need k*1024 x 32 x 8 x 1)",
             NumWords, DataWidth, ByteWidth, NumPorts);
    end
  end
`endif
// pragma translate_on

  // Unused ports (NumPorts is expected to be 1)
  for (genvar p = 1; p < NumPorts; p++) begin : gen_unused_ports
    assign rdata_o[p] = '0;
  end

`ifdef TARGET_SYNTHESIS
  // ===========================================================================
  // Macro view: N x sram_32x1024
  // ===========================================================================
  localparam int unsigned MacroWords    = 32'd1024;
  localparam int unsigned MacroAddrBits = 32'd10;                    // $clog2(MacroWords)
  localparam int unsigned NumMacros     = NumWords / MacroWords;     // e.g. 4096 -> 4
  localparam int unsigned SelBits       = AddrWidth - MacroAddrBits; // e.g. 4096 -> 2

  // Power pins: connected to the core PDN by LibreLane (same as the cluster TCDM).
`ifdef USE_POWER_PINS
  wire vccd1;
  wire vssd1;
`endif

  logic [MacroAddrBits-1:0] macro_addr;

  assign macro_addr = addr_i[0][MacroAddrBits-1:0];

  if (NumMacros == 1) begin : gen_single
    // ---- one macro: no select logic needed ----
    logic [32:0] dout0;

    sram_32x1024 u_sram (
`ifdef USE_POWER_PINS
      .vccd1      ( vccd1                  ),
      .vssd1      ( vssd1                  ),
`endif
      .clk0       ( clk_i                  ),
      .csb0       ( ~req_i[0]              ),  // active-low chip select
      .web0       ( ~we_i[0]               ),  // active-low write enable
      .wmask0     ( be_i[0]                ),  // 4-bit byte mask, active-high
      .spare_wen0 ( 1'b0                   ),
      .addr0      ( {1'b0, macro_addr}     ),  // spare row  => 11-bit address
      .din0       ( {1'b0, wdata_i[0]}     ),  // spare col  => 33-bit data
      .dout0      ( dout0                  )
    );

    assign rdata_o[0] = dout0[31:0];

  end else begin : gen_multi
    // ---- several macros: upper address bits select the macro ----
    logic [SelBits-1:0]                  macro_sel;
    logic [SelBits-1:0]                  macro_sel_q;
    logic [NumMacros-1:0][DataWidth-1:0] dout_bus;   // read data, one slice per macro

    assign macro_sel = addr_i[0][AddrWidth-1:MacroAddrBits];

    // The macro returns read data one cycle after the request, so the select
    // is registered to line up the output mux with the data.
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        macro_sel_q <= '0;
      end else if (req_i[0]) begin
        macro_sel_q <= macro_sel;
      end
    end

    for (genvar m = 0; m < NumMacros; m++) begin : gen_macro
      logic        csb0;
      logic [32:0] dout0;

      // enabled only on a request that targets this macro
      assign csb0 = ~req_i[0] | (macro_sel != SelBits'(m));

      sram_32x1024 u_sram (
`ifdef USE_POWER_PINS
        .vccd1      ( vccd1                  ),
        .vssd1      ( vssd1                  ),
`endif
        .clk0       ( clk_i                  ),
        .csb0       ( csb0                   ),
        .web0       ( ~we_i[0]               ),
        .wmask0     ( be_i[0]                ),
        .spare_wen0 ( 1'b0                   ),
        .addr0      ( {1'b0, macro_addr}     ),
        .din0       ( {1'b0, wdata_i[0]}     ),
        .dout0      ( dout0                  )
      );

      assign dout_bus[m] = dout0[31:0];
    end

    assign rdata_o[0] = dout_bus[macro_sel_q];
  end

`else
  // ===========================================================================
  // Behavioral view (RTL simulation): 1-cycle read latency like the macro
  // ===========================================================================
  logic [DataWidth-1:0] mem [NumWords];

  always_ff @(posedge clk_i) begin
    if (req_i[0]) begin
      if (we_i[0]) begin
        for (int unsigned j = 0; j < BeWidth; j++) begin
          if (be_i[0][j]) mem[addr_i[0]][j*ByteWidth +: ByteWidth] <= wdata_i[0][j*ByteWidth +: ByteWidth];
        end
      end else begin
        rdata_o[0] <= mem[addr_i[0]];
      end
    end
  end
`endif

endmodule
