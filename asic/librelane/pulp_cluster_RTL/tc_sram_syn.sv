/*
copy from /home/ahmed/pulp_workspace/pulp/.bender/git/checkouts/tech_cells_generic-6a4b27e0e56cbcda/src/rtl/tc_sram.sv
module used here for synthesis
Wrapper around OpenRAM macro sram_32x1024 (1024x32, 1RW).
Used for TCDM banks: NumWords=1024, DataWidth=32, NumPorts=1, ByteWidth=8.
Yosys flattens tc_sram but keeps sram_32x1024 as macro (see MACROS in config.yaml).
*/
module tc_sram_syn #(
  parameter int unsigned NumWords     = 32'd1024, // Number of Words in data array
  parameter int unsigned DataWidth    = 32'd128,  // Data signal width
  parameter int unsigned ByteWidth    = 32'd8,    // Width of a data byte
  parameter int unsigned NumPorts     = 32'd2,    // Number of read and write ports
  parameter int unsigned Latency      = 32'd1,    // Latency when the read data is available
  parameter              SimInit      = "none",   // Simulation initialization
  parameter bit          PrintSimCfg  = 1'b0,     // Print configuration
  // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
  parameter int unsigned AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1,
  parameter int unsigned BeWidth   = (DataWidth + ByteWidth - 32'd1) / ByteWidth // ceil_div (removed comma)
) (
  input  logic                                 clk_i,      // Clock
  input  logic                                 rst_ni,     // Asynchronous reset active low
  // input ports
  input  logic  [NumPorts-1:0]                 req_i,      // request
  input  logic  [NumPorts-1:0]                 we_i,       // write enable
  input  logic  [NumPorts-1:0][AddrWidth-1:0]  addr_i,     // request address
  input  logic  [NumPorts-1:0][DataWidth-1:0]  wdata_i,    // write data
  input  logic  [NumPorts-1:0][BeWidth-1:0]    be_i,       // write byte enable
  // output ports
  output logic  [NumPorts-1:0][DataWidth-1:0]  rdata_o     // read data
);
  // This wrapper only supports the hardened configuration used by
  // tcdm_banks_wrap: 1024 words x 32 bit, 1 port, 8-bit byte enables.
  // Other parameterizations will fail simulation here instead of silently
  // mismatching the sram_32x1024 macro.
// pragma translate_off
`ifndef SYNTHESIS
  initial begin
    if (NumWords != 1024 || DataWidth != 32 || NumPorts != 1 || ByteWidth != 8) begin
      $fatal(1, "tc_sram macro wrapper only supports 1024x32x1 (got %0d x %0d x %0d)",
             NumWords, DataWidth, NumPorts);
    end
  end
`endif
// pragma translate_on

`ifdef __pnr__
  // PnR view: bind port 0 to the OpenRAM hard macro.
  // OpenRAM has 1 spare row/col, hence 11-bit addr and 33-bit data.
`ifdef USE_POWER_PINS
  wire vccd1;
  wire vssd1;
`endif
  wire        csb0 = ~req_i[0];
  wire        web0 = ~we_i[0];
  wire [10:0] addr0 = {1'b0, addr_i[0]};
  wire [32:0] din0  = {1'b0, wdata_i[0]};
  wire [32:0] dout0;

  assign rdata_o[0] = dout0[31:0];

  sram_32x1024 u_sram (
`ifdef USE_POWER_PINS
    .vccd1      (vccd1),
    .vssd1      (vssd1),
`endif
    .clk0       (clk_i),
    .csb0       (csb0),
    .web0       (web0),
    .addr0      (addr0),
    .wmask0     (be_i[0]),
    .spare_wen0 (1'b0),
    .din0       (din0),
    .dout0      (dout0)
  );
`else
  // Simulation view: behavioral single-port SRAM (macro model in
  // pulp_tcdm_sram/macro/sram_32x1024/sram_32x1024.v is bit-compatible).
  logic [DataWidth-1:0] mem [NumWords-1:0];
  always_ff @(posedge clk_i) begin
    if (req_i[0]) begin
      if (we_i[0]) begin
        for (int j = 0; j < BeWidth; j++) begin
          if (be_i[0][j]) mem[addr_i[0]][j*ByteWidth +: ByteWidth] <= wdata_i[0][j*ByteWidth +: ByteWidth];
        end
      end else begin
        rdata_o[0] <= mem[addr_i[0]];
      end
    end
  end
  // Tie off unused ports if parameterized with NumPorts > 1 (not used by TCDM).
  generate
    if (NumPorts > 1) begin : gen_unused_ports
      for (genvar p = 1; p < NumPorts; p++) begin : gen_p
        assign rdata_o[p] = '0;
      end
    end
  endgenerate
`endif
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
`ifdef USE_POWER_PINS
      // Declare wires to drive the inout power ports safely
      wire pwr_vccd1;
      wire pwr_vssd1;
      assign pwr_vccd1 = 1'b1;
      assign pwr_vssd1 = 1'b0;
`endif
      sky130_sram_1kbyte_1rw1r_32x256_8 sram_hard_macro (
`ifdef USE_POWER_PINS
        .vccd1 (pwr_vccd1),
        .vssd1 (pwr_vssd1),
`endif
        // ----------------------------------------------------
        // Port 0: Read / Write (Driven by tc_sram port 0)
        // ----------------------------------------------------
        .clk0   (clk_i),
        .csb0   (~req_i[0]),       // Invert active-high request to active-low chip select
        .web0   (~we_i[0]),        // Invert active-high write enable to active-low
        .wmask0 (be_i[0]),         // 4-bit byte enable mask
        .addr0  (addr_i[0]),       // 8-bit address
        .din0   (wdata_i[0]),      // 32-bit write data
        .dout0  (rdata_o[0]),      // 32-bit read data

        // ----------------------------------------------------
        // Port 1: Read-Only (Driven by tc_sram port 1)
        // ----------------------------------------------------
        .clk1   (clk_i),
        .csb1   (~req_i[1]),       // Invert active-high request
        .addr1  (addr_i[1]),       // 8-bit address
        .dout1  (rdata_o[1])       // 32-bit read data
      );

      // Note: we_i[1], wdata_i[1], and be_i[1] from tc_sram are unused 
      // here because Port 1 on the Sky130 macro physically cannot write.
*/
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/*

  // memory array
  data_t sram [NumWords-1:0];
  // hold the read address when no read access is made
  addr_t [NumPorts-1:0] r_addr_q;

  // SRAM simulation initialization
  data_t [NumWords-1:0] init_val;
  initial begin : proc_sram_init
    for (int unsigned i = 0; i < NumWords; i++) begin
      for (int unsigned j = 0; j < DataWidth; j++) begin
        case (SimInit)
          "zeros":  init_val[i][j] = 1'b0;
          "ones":   init_val[i][j] = 1'b1;
          "random": init_val[i][j] = $urandom();
          default:  init_val[i][j] = 1'bx;
        endcase
      end
    end
  end

  // set the read output if requested
  // The read data at the highest array index is set combinational.
  // It gets then delayed for a number of cycles until it gets available at the output at
  // array index 0.

  // read data output assignment
  data_t [NumPorts-1:0][Latency-1:0] rdata_q,  rdata_d;
  if (Latency == 32'd0) begin : gen_no_read_lat
    for (genvar i = 0; i < NumPorts; i++) begin : gen_port
      assign rdata_o[i] = (req_i[i] && !we_i[i]) ? sram[addr_i[i]] : sram[r_addr_q[i]];
    end
  end else begin : gen_read_lat

    always_comb begin
      for (int unsigned i = 0; i < NumPorts; i++) begin
        rdata_o[i] = rdata_q[i][0];
        for (int unsigned j = 0; j < (Latency-1); j++) begin
          rdata_d[i][j] = rdata_q[i][j+1];
        end
        rdata_d[i][Latency-1] = (req_i[i] && !we_i[i]) ? sram[addr_i[i]] : sram[r_addr_q[i]];
      end
    end
  end

  // write memory array
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int unsigned i = 0; i < NumWords; i++) begin
        sram[i] <= init_val[i];
      end
      for (int i = 0; i < NumPorts; i++) begin
        r_addr_q[i] <= {AddrWidth{1'b0}};
        // initialize the read output register for each port
        if (Latency != 32'd0) begin
          for (int unsigned j = 0; j < Latency; j++) begin
            rdata_q[i][j] <= init_val[{AddrWidth{1'b0}}];
          end
        end
      end
    end else begin
      // read value latch happens before new data is written to the sram
      for (int unsigned i = 0; i < NumPorts; i++) begin
        if (Latency != 0) begin
          for (int unsigned j = 0; j < Latency; j++) begin
            rdata_q[i][j] <= rdata_d[i][j];
          end
        end
      end
      // there is a request for the SRAM, latch the required register
      for (int unsigned i = 0; i < NumPorts; i++) begin
        if (req_i[i]) begin
          if (we_i[i]) begin
            // update value when write is set at clock
            for (int unsigned j = 0; j < DataWidth; j++) begin
              if (be_i[i][j/ByteWidth]) begin
                sram[addr_i[i]][j] <= wdata_i[i][j];
              end
            end
          end else begin
            // otherwise update read address for subsequent non request cycles
            r_addr_q[i] <= addr_i[i];
          end
        end // if req_i
      end // for ports
    end // if !rst_ni
  end

// Validate parameters.
// pragma translate_off
`ifndef VERILATOR
`ifndef TARGET_SYNTHESIS
  initial begin: p_assertions
    assert ($bits(addr_i)  == NumPorts * AddrWidth) else $fatal(1, "AddrWidth problem on `addr_i`");
    assert ($bits(wdata_i) == NumPorts * DataWidth) else $fatal(1, "DataWidth problem on `wdata_i`");
    assert ($bits(be_i)    == NumPorts * BeWidth)   else $fatal(1, "BeWidth   problem on `be_i`"   );
    assert ($bits(rdata_o) == NumPorts * DataWidth) else $fatal(1, "DataWidth problem on `rdata_o`");
    assert (NumWords  >= 32'd1) else $fatal(1, "NumWords has to be > 0");
    assert (DataWidth >= 32'd1) else $fatal(1, "DataWidth has to be > 0");
    assert (ByteWidth >= 32'd1) else $fatal(1, "ByteWidth has to be > 0");
    assert (NumPorts  >= 32'd1) else $fatal(1, "The number of ports must be at least 1!");
  end
  initial begin: p_sim_hello
    if (PrintSimCfg) begin
      $display("#################################################################################");
      $display("tc_sram functional instantiated with the configuration:"                          );
      $display("Instance: %m"                                                                     );
      $display("Number of ports   (dec): %0d", NumPorts                                           );
      $display("Number of words   (dec): %0d", NumWords                                           );
      $display("Address width     (dec): %0d", AddrWidth                                          );
      $display("Data width        (dec): %0d", DataWidth                                          );
      $display("Byte width        (dec): %0d", ByteWidth                                          );
      $display("Byte enable width (dec): %0d", BeWidth                                            );
      $display("Latency Cycles    (dec): %0d", Latency                                            );
      $display("Simulation init   (str): %0s", SimInit                                            );
      $display("#################################################################################");
    end
  end
  for (genvar i = 0; i < NumPorts; i++) begin : gen_assertions
    assert property ( @(posedge clk_i) disable iff (!rst_ni)
        (req_i[i] |-> (addr_i[i] < NumWords))) else
      $warning("Request address %0h not mapped, port %0d, expect random write or read behavior!",
          addr_i[i], i);
  end

`endif
`endif
// pragma translate_on

*/
endmodule
