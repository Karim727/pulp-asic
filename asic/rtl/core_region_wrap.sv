// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

/*
 * core_region_wrap.sv
 * Synthesis wrapper for core_region dissolving SystemVerilog interfaces
 * into discrete I/O ports.
 */

`include "pulp_soc_defines.sv"
`include "periph_bus_defines.sv"

module core_region_wrap
#(
  // CORE PARAMETERS
  parameter CORE_TYPE_CL        = 0,  // 0 for RISCY, 1 for IBEX RV32IMC, 2 for IBEX RV32EC
  parameter N_EXT_PERF_COUNTERS = 1,
  parameter CORE_ID             = 0,
  parameter ADDR_WIDTH          = 32,
  parameter DATA_WIDTH          = 32,
  parameter INSTR_RDATA_WIDTH   = 32,
  parameter CLUSTER_ALIAS_BASE  = 12'h000,
  parameter REMAP_ADDRESS       = 0,

  parameter APU_NARGS_CPU       = 2,
  parameter APU_WOP_CPU         = 1,
  parameter WAPUTYPE            = 3,
  parameter APU_NDSFLAGS_CPU    = 3,
  parameter APU_NUSFLAGS_CPU    = 5,
  
  parameter FPU                 = 0,
  parameter FP_DIVSQRT          = 0,
  parameter SHARED_FP           = 0,
  parameter SHARED_FP_DIVSQRT   = 0,

  parameter DEBUG_START_ADDR    = `DEBUG_START_ADDR,

  parameter L2_SLM_FILE         = "./slm_files/l2_stim.slm",
  parameter ROM_SLM_FILE        = "../sw/apps/boot/slm_files/l2_stim.slm"
)
(
`ifdef USE_POWER_PINS
  inout logic                            power,
  inout logic                            ground,
`endif

  input logic                            clk_i,
  input logic                            rst_ni,
  input logic                            init_ni,

  input logic [3:0]                      base_addr_i, // FOR CLUSTER VIRTUALIZATION

  input logic [5:0]                      cluster_id_i,
  input logic [3:0]                      core_id_i = CORE_ID[3:0],
  
  input logic                            irq_req_i,
  output logic                           irq_ack_o,
  input logic [4:0]                      irq_id_i,
  output logic [4:0]                     irq_ack_id_o,
  
  input logic                            clock_en_i,
  input logic                            fetch_en_i,
  input logic                            fregfile_disable_i,

  input logic [31:0]                     boot_addr_i,

  input logic                            test_mode_i,

  output logic                           core_busy_o,

  // Interface to Instruction Logarithmic interconnect (Req->grant handshake)
  output logic                           instr_req_o,
  input logic                            instr_gnt_i,
  output logic [31:0]                    instr_addr_o,
  input logic [INSTR_RDATA_WIDTH-1:0]    instr_r_rdata_i,
  input logic                            instr_r_valid_i,

  input logic                            debug_req_i,
              
  // Interface for DEMUX to TCDM INTERCONNECT, PERIPHERAL INTERCONNECT and DMA CONTROLLER
  // TCDM Master (discrete ports for HCI)
  output logic                           tcdm_data_req_o,
  input  logic                           tcdm_data_gnt_i,
  output logic [ADDR_WIDTH-1:0]          tcdm_data_add_o,
  output logic                           tcdm_data_wen_o,
  output logic [DATA_WIDTH-1:0]          tcdm_data_wdata_o,
  output logic [DATA_WIDTH/8-1:0]        tcdm_data_be_o,
  input  logic [DATA_WIDTH-1:0]          tcdm_data_r_rdata_i,
  input  logic                           tcdm_data_r_valid_i,

  // DMA Controller Master
  output logic                           dma_ctrl_req_o,
  output logic [31:0]                    dma_ctrl_add_o,
  output logic                           dma_ctrl_wen_o,
  output logic [31:0]                    dma_ctrl_wdata_o,
  output logic [3:0]                     dma_ctrl_be_o,
  input  logic                           dma_ctrl_gnt_i,
  input  logic                           dma_ctrl_r_valid_i,
  input  logic [31:0]                    dma_ctrl_r_rdata_i,
  input  logic                           dma_ctrl_r_opc_i,

  // Event Unit Controller Master
  output logic                           eu_ctrl_req_o,
  output logic [31:0]                    eu_ctrl_add_o,
  output logic                           eu_ctrl_wen_o,
  output logic [31:0]                    eu_ctrl_wdata_o,
  output logic [3:0]                     eu_ctrl_be_o,
  input  logic                           eu_ctrl_gnt_i,
  input  logic                           eu_ctrl_r_valid_i,
  input  logic [31:0]                    eu_ctrl_r_rdata_i,
  input  logic                           eu_ctrl_r_opc_i,

  // Peripheral Data Master
  output logic                           periph_data_req_o,
  output logic [31:0]                    periph_data_add_o,
  output logic                           periph_data_wen_o,
  output logic [31:0]                    periph_data_wdata_o,
  output logic [3:0]                     periph_data_be_o,
  input  logic                           periph_data_gnt_i,
  input  logic                           periph_data_r_valid_i,
  input  logic [31:0]                    periph_data_r_rdata_i,
  input  logic                           periph_data_r_opc_i

`ifdef SHARED_FPU_CLUSTER
  ,
  output logic                           apu_master_req_o,
  input logic                            apu_master_gnt_i,
  output logic [WAPUTYPE-1:0]            apu_master_type_o,
  output logic [APU_NARGS_CPU-1:0][31:0] apu_master_operands_o,
  output logic [APU_WOP_CPU-1:0]         apu_master_op_o,
  output logic [APU_NDSFLAGS_CPU-1:0]    apu_master_flags_o,
  output logic                           apu_master_ready_o,
  input logic                            apu_master_valid_i,
  input logic [31:0]                     apu_master_result_i,
  input logic [APU_NUSFLAGS_CPU-1:0]     apu_master_flags_i
`endif

`ifdef APU_CLUSTER
  ,
  output logic                           apu_master_req_o,
  input logic                            apu_master_gnt_i,
  output logic [WAPUTYPE-1:0]            apu_master_type_o,
  output logic [APU_NARGS_CPU-1:0][31:0] apu_master_operands_o,
  output logic [APU_WOP_CPU-1:0]         apu_master_op_o,
  output logic [APU_NDSFLAGS_CPU-1:0]    apu_master_flags_o,
  output logic                           apu_master_ready_o,
  input logic                            apu_master_valid_i,
  input logic [31:0]                     apu_master_result_i,
  input logic [APU_NUSFLAGS_CPU-1:0]     apu_master_flags_i
`endif
);

  // Internal interface instances to bind to core_region
  hci_core_intf #(
    .DW ( DATA_WIDTH ),
    .AW ( ADDR_WIDTH ),
    .OW ( 1          )
  ) tcdm_data_master (
    .clk ( clk_i )
  );

  XBAR_TCDM_BUS   dma_ctrl_master ();
  XBAR_PERIPH_BUS eu_ctrl_master ();
  XBAR_PERIPH_BUS periph_data_master ();

  // TCDM Master bindings
  assign tcdm_data_req_o            = tcdm_data_master.req;
  assign tcdm_data_add_o            = tcdm_data_master.add;
  assign tcdm_data_wen_o            = tcdm_data_master.wen;
  assign tcdm_data_wdata_o          = tcdm_data_master.data;
  assign tcdm_data_be_o             = tcdm_data_master.be;
  assign tcdm_data_master.gnt       = tcdm_data_gnt_i;
  assign tcdm_data_master.r_valid   = tcdm_data_r_valid_i;
  assign tcdm_data_master.r_data    = tcdm_data_r_rdata_i;
  assign tcdm_data_master.r_opc     = 1'b0;
  assign tcdm_data_master.r_user    = '0;

  // DMA Controller Master bindings
  assign dma_ctrl_req_o             = dma_ctrl_master.req;
  assign dma_ctrl_add_o             = dma_ctrl_master.add;
  assign dma_ctrl_wen_o             = dma_ctrl_master.wen;
  assign dma_ctrl_wdata_o           = dma_ctrl_master.wdata;
  assign dma_ctrl_be_o              = dma_ctrl_master.be;
  assign dma_ctrl_master.gnt        = dma_ctrl_gnt_i;
  assign dma_ctrl_master.r_valid    = dma_ctrl_r_valid_i;
  assign dma_ctrl_master.r_rdata    = dma_ctrl_r_rdata_i;
  assign dma_ctrl_master.r_opc      = dma_ctrl_r_opc_i;

  // Event Unit Controller Master bindings
  assign eu_ctrl_req_o              = eu_ctrl_master.req;
  assign eu_ctrl_add_o              = eu_ctrl_master.add;
  assign eu_ctrl_wen_o              = eu_ctrl_master.wen;
  assign eu_ctrl_wdata_o            = eu_ctrl_master.wdata;
  assign eu_ctrl_be_o               = eu_ctrl_master.be;
  assign eu_ctrl_master.gnt         = eu_ctrl_gnt_i;
  assign eu_ctrl_master.r_valid     = eu_ctrl_r_valid_i;
  assign eu_ctrl_master.r_rdata     = eu_ctrl_r_rdata_i;
  assign eu_ctrl_master.r_opc       = eu_ctrl_r_opc_i;
  assign eu_ctrl_master.r_id        = '0;

  // Peripheral Data Master bindings
  assign periph_data_req_o          = periph_data_master.req;
  assign periph_data_add_o          = periph_data_master.add;
  assign periph_data_wen_o          = periph_data_master.wen;
  assign periph_data_wdata_o        = periph_data_master.wdata;
  assign periph_data_be_o           = periph_data_master.be;
  assign periph_data_master.gnt     = periph_data_gnt_i;
  assign periph_data_master.r_valid = periph_data_r_valid_i;
  assign periph_data_master.r_rdata = periph_data_r_rdata_i;
  assign periph_data_master.r_opc   = periph_data_r_opc_i;
  assign periph_data_master.r_id    = '0;

  // Instantiation of the original, unmodified core_region
  core_region #(
    .CORE_TYPE_CL        ( CORE_TYPE_CL        ),
    .N_EXT_PERF_COUNTERS ( N_EXT_PERF_COUNTERS ),
    .CORE_ID             ( CORE_ID             ),
    .ADDR_WIDTH          ( ADDR_WIDTH          ),
    .DATA_WIDTH          ( DATA_WIDTH          ),
    .INSTR_RDATA_WIDTH   ( INSTR_RDATA_WIDTH   ),
    .CLUSTER_ALIAS_BASE  ( CLUSTER_ALIAS_BASE  ),
    .REMAP_ADDRESS       ( REMAP_ADDRESS       ),
    .APU_NARGS_CPU       ( APU_NARGS_CPU       ),
    .APU_WOP_CPU         ( APU_WOP_CPU         ),
    .WAPUTYPE            ( WAPUTYPE            ),
    .APU_NDSFLAGS_CPU    ( APU_NDSFLAGS_CPU    ),
    .APU_NUSFLAGS_CPU    ( APU_NUSFLAGS_CPU    ),
    .FPU                 ( FPU                 ),
    .FP_DIVSQRT          ( FP_DIVSQRT          ),
    .SHARED_FP           ( SHARED_FP           ),
    .SHARED_FP_DIVSQRT   ( SHARED_FP_DIVSQRT   ),
    .DEBUG_START_ADDR    ( DEBUG_START_ADDR    ),
    .L2_SLM_FILE         ( L2_SLM_FILE         ),
    .ROM_SLM_FILE        ( ROM_SLM_FILE        )
  ) i_core_region (
    .clk_i               ( clk_i               ),
    .rst_ni              ( rst_ni              ),
    .init_ni             ( init_ni             ),
    .base_addr_i         ( base_addr_i         ),
    .cluster_id_i        ( cluster_id_i        ),
    .core_id_i           ( core_id_i           ),
    .irq_req_i           ( irq_req_i           ),
    .irq_ack_o           ( irq_ack_o           ),
    .irq_id_i            ( irq_id_i            ),
    .irq_ack_id_o        ( irq_ack_id_o        ),
    .clock_en_i          ( clock_en_i          ),
    .fetch_en_i          ( fetch_en_i          ),
    .fregfile_disable_i  ( fregfile_disable_i  ),
    .boot_addr_i         ( boot_addr_i         ),
    .test_mode_i         ( test_mode_i         ),
    .core_busy_o         ( core_busy_o         ),
    .instr_req_o         ( instr_req_o         ),
    .instr_gnt_i         ( instr_gnt_i         ),
    .instr_addr_o        ( instr_addr_o        ),
    .instr_r_rdata_i     ( instr_r_rdata_i     ),
    .instr_r_valid_i     ( instr_r_valid_i     ),
    .debug_req_i         ( debug_req_i         ),
    .tcdm_data_master    ( tcdm_data_master    ),
    .dma_ctrl_master     ( dma_ctrl_master     ),
    .eu_ctrl_master      ( eu_ctrl_master      ),
    .periph_data_master  ( periph_data_master  )
`ifdef SHARED_FPU_CLUSTER
    ,
    .apu_master_req_o      ( apu_master_req_o      ),
    .apu_master_gnt_i      ( apu_master_gnt_i      ),
    .apu_master_type_o     ( apu_master_type_o     ),
    .apu_master_operands_o ( apu_master_operands_o ),
    .apu_master_op_o       ( apu_master_op_o       ),
    .apu_master_flags_o    ( apu_master_flags_o    ),
    .apu_master_ready_o    ( apu_master_ready_o    ),
    .apu_master_valid_i    ( apu_master_valid_i    ),
    .apu_master_result_i   ( apu_master_result_i   ),
    .apu_master_flags_i    ( apu_master_flags_i    )
`endif
`ifdef APU_CLUSTER
    ,
    .apu_master_req_o      ( apu_master_req_o      ),
    .apu_master_gnt_i      ( apu_master_gnt_i      ),
    .apu_master_type_o     ( apu_master_type_o     ),
    .apu_master_operands_o ( apu_master_operands_o ),
    .apu_master_op_o       ( apu_master_op_o       ),
    .apu_master_flags_o    ( apu_master_flags_o    ),
    .apu_master_ready_o    ( apu_master_ready_o    ),
    .apu_master_valid_i    ( apu_master_valid_i    ),
    .apu_master_result_i   ( apu_master_result_i   ),
    .apu_master_flags_i    ( apu_master_flags_i    )
`endif
  );

endmodule
