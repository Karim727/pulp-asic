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
 * core_region.sv
 * Synthesis-ready version with discrete ports for ASIC flow
 */

`include "pulp_soc_defines.sv"
`include "periph_bus_defines.sv"

module core_region
#(
  // CORE PARAMETERS
  parameter CORE_TYPE_CL        = 0,  // 0 for RISCY/CV32E40P, 1 for IBEX RV32IMC, 2 for IBEX RV32EC
  parameter N_EXT_PERF_COUNTERS = 1,
  parameter CORE_ID             = 0,
  parameter ADDR_WIDTH          = 32,
  parameter DATA_WIDTH          = 32,
  parameter INSTR_RDATA_WIDTH   = 32,
  parameter CLUSTER_ALIAS_BASE  = 12'h000,
  parameter REMAP_ADDRESS       = 0,

  parameter APU_NARGS_CPU       = 3,
  parameter APU_WOP_CPU         = 6,
  parameter WAPUTYPE            = 3,
  parameter APU_NDSFLAGS_CPU    = 15,
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

  localparam N_EXT_PERF_COUNTERS_ACTUAL = 5;

  //********************************************************
  //***************** SIGNALS DECLARATION ******************
  //********************************************************

  // Internal connection between CORE <--> DEMUX
  logic        s_core_bus_req;
  logic [31:0] s_core_bus_add;
  logic        s_core_bus_we;
  logic [31:0] s_core_bus_wdata;
  logic [3:0]  s_core_bus_be;
  logic        s_core_bus_gnt;
  logic [31:0] s_core_bus_r_rdata;
  logic        s_core_bus_r_valid;

  // Internal connection between CORE_DEMUX <--> PERIPHERAL DEMUX
  logic        periph_demux_bus_req;
  logic [31:0] periph_demux_bus_add;
  logic        periph_demux_bus_wen;
  logic [31:0] periph_demux_bus_wdata;
  logic [3:0]  periph_demux_bus_be;
  logic        periph_demux_bus_gnt;
  logic        periph_demux_bus_r_valid;
  logic [31:0] periph_demux_bus_r_rdata;
  logic        periph_demux_bus_r_opc;

  logic [N_EXT_PERF_COUNTERS_ACTUAL-1:0]      perf_counters;
  logic            clk_int;
  logic [31:0]     hart_id;
  logic [31:0]     boot_addr;

  // Clock gate of the core_region less the core itself
  cluster_clock_gating clock_gate_i (
    .clk_i     ( clk_i       ),
    .en_i      ( clock_en_i  ),
    .test_en_i ( test_mode_i ),
    .clk_o     ( clk_int     )
  );

  assign hart_id = {21'b0, cluster_id_i[5:0], 1'b0, CORE_ID[3:0]};

`ifndef APU_CLUSTER
 `ifndef SHARED_FPU_CLUSTER
  // APU tie-offs when no APU/FPU:
  logic                           apu_master_req_o;
  logic                           apu_master_gnt_i;
  logic [WAPUTYPE-1:0]            apu_master_type_o;
  logic [APU_NARGS_CPU-1:0][31:0] apu_master_operands_o;
  logic [APU_WOP_CPU-1:0]         apu_master_op_o;
  logic [APU_NDSFLAGS_CPU-1:0]    apu_master_flags_o;
  logic                           apu_master_ready_o;
  logic                           apu_master_valid_i;
  logic [31:0]                    apu_master_result_i;
  logic [APU_NUSFLAGS_CPU-1:0]    apu_master_flags_i;

  assign apu_master_gnt_i      = '1;
  assign apu_master_valid_i    = '0;
  assign apu_master_result_i   = '0;
  assign apu_master_flags_i    = '0;
 `endif
`endif

  //********************************************************
  //***************** PROCESSOR ****************************
  //********************************************************

  generate
    if ( CORE_TYPE_CL == 0 ) begin: CL_CORE
      assign boot_addr = boot_addr_i;
      riscv_core #(
        .INSTR_RDATA_WIDTH   ( INSTR_RDATA_WIDTH ),
        .N_EXT_PERF_COUNTERS ( N_EXT_PERF_COUNTERS_ACTUAL ),
        .PULP_SECURE         ( 0                 ),
        .FPU                 ( FPU               ),
        .FP_DIVSQRT          ( FP_DIVSQRT        ),
        .SHARED_FP           ( SHARED_FP         ),
        .SHARED_DSP_MULT     ( 0                 ),
        .SHARED_INT_DIV      ( 0                 ),
        .SHARED_FP_DIVSQRT   ( SHARED_FP_DIVSQRT ),
        .WAPUTYPE            ( WAPUTYPE          ),
        .APU_NARGS_CPU       ( APU_NARGS_CPU     ),
        .APU_WOP_CPU         ( APU_WOP_CPU       ),
        .APU_NDSFLAGS_CPU    ( APU_NDSFLAGS_CPU  ),
        .APU_NUSFLAGS_CPU    ( APU_NUSFLAGS_CPU  ),
        .DM_HaltAddress      ( DEBUG_START_ADDR + 16'h0800 )

      ) RISCV_CORE (
        .clk_i                 ( clk_i                    ),
        .rst_ni                ( rst_ni                   ),

        .clock_en_i            ( clock_en_i               ),
        .test_en_i             ( test_mode_i              ),

        .boot_addr_i           ( boot_addr                ),
        .core_id_i             ( CORE_ID[3:0]             ),
        .cluster_id_i          ( cluster_id_i             ),

        .instr_addr_o          ( instr_addr_o             ),
        .instr_req_o           ( instr_req_o              ),
        .instr_rdata_i         ( instr_r_rdata_i          ),
        .instr_gnt_i           ( instr_gnt_i              ),
        .instr_rvalid_i        ( instr_r_valid_i          ),

        .data_addr_o           ( s_core_bus_add           ),
        .data_wdata_o          ( s_core_bus_wdata         ),
        .data_we_o             ( s_core_bus_we            ),
        .data_req_o            ( s_core_bus_req           ),
        .data_be_o             ( s_core_bus_be            ),
        .data_rdata_i          ( s_core_bus_r_rdata       ),
        .data_gnt_i            ( s_core_bus_gnt           ),
        .data_rvalid_i         ( s_core_bus_r_valid       ),

        .irq_i                 ( irq_req_i                ),
        .irq_id_i              ( irq_id_i                 ),
        .irq_id_o              ( irq_ack_id_o             ),
        .irq_ack_o             ( irq_ack_o                ),

        .sec_lvl_o             (                          ),
        .irq_sec_i             ( 1'b0                     ),

        .debug_req_i           ( debug_req_i              ),

        .fetch_enable_i        ( fetch_en_i               ),
        .core_busy_o           ( core_busy_o              ),

        .apu_master_req_o      ( apu_master_req_o         ),
        .apu_master_gnt_i      ( apu_master_gnt_i         ),
        .apu_master_type_o     ( apu_master_type_o        ),
        .apu_master_operands_o ( apu_master_operands_o    ),
        .apu_master_op_o       ( apu_master_op_o          ),
        .apu_master_flags_o    ( apu_master_flags_o       ),

        .apu_master_valid_i    ( apu_master_valid_i       ),
        .apu_master_ready_o    ( apu_master_ready_o       ),
        .apu_master_result_i   ( apu_master_result_i      ),
        .apu_master_flags_i    ( apu_master_flags_i       ),

        .ext_perf_counters_i   ( perf_counters            ),
        .fregfile_disable_i    ( 1'b1                     )
      ); 
    end
  endgenerate

  // Performance Counters
  assign perf_counters[4] = tcdm_data_req_o & (~tcdm_data_gnt_i);

  //********************************************************
  //****** DEMUX TO TCDM AND PERIPHERAL INTERCONNECT *******
  //********************************************************
   
  core_demux #(
    .ADDR_WIDTH         ( 32                 ),
    .DATA_WIDTH         ( 32                 ),
    .BYTE_ENABLE_BIT    ( DATA_WIDTH/8       ),
    .CLUSTER_ALIAS_BASE ( CLUSTER_ALIAS_BASE )
  ) core_demux_i (
    .clk                (  clk_int                    ),
    .rst_ni             (  rst_ni                     ),
    .test_en_i          (  test_mode_i                ),
  `ifdef REMAP_ADDRESS
    .base_addr_i        (  base_addr_i                ),
  `endif
    .data_req_i         (  s_core_bus_req             ),
    .data_add_i         (  s_core_bus_add             ),
    .data_wen_i         ( ~s_core_bus_we              ),
    .data_wdata_i       (  s_core_bus_wdata           ),
    .data_be_i          (  s_core_bus_be              ),
    .data_gnt_o         (  s_core_bus_gnt             ),
    .data_r_gnt_i       (  1'b0                       ),
    .data_r_valid_o     (  s_core_bus_r_valid         ),
    .data_r_opc_o       (                             ),
    .data_r_rdata_o     (  s_core_bus_r_rdata         ),

    .data_req_o_SH      (  tcdm_data_req_o            ),
    .data_add_o_SH      (  tcdm_data_add_o            ),
    .data_wen_o_SH      (  tcdm_data_wen_o            ),
    .data_wdata_o_SH    (  tcdm_data_wdata_o          ),
    .data_be_o_SH       (  tcdm_data_be_o             ),
    .data_gnt_i_SH      (  tcdm_data_gnt_i            ),
    .data_r_valid_i_SH  (  tcdm_data_r_valid_i        ),
    .data_r_rdata_i_SH  (  tcdm_data_r_rdata_i        ),

    .data_req_o_EXT     (  periph_demux_bus_req       ),
    .data_add_o_EXT     (  periph_demux_bus_add       ),
    .data_wen_o_EXT     (  periph_demux_bus_wen       ),
    .data_wdata_o_EXT   (  periph_demux_bus_wdata     ),
    .data_be_o_EXT      (  periph_demux_bus_be        ),
    .data_gnt_i_EXT     (  periph_demux_bus_gnt       ),
    .data_r_valid_i_EXT (  periph_demux_bus_r_valid   ),
    .data_r_rdata_i_EXT (  periph_demux_bus_r_rdata   ),
    .data_r_opc_i_EXT   (  periph_demux_bus_r_opc     ),

    .data_req_o_PE      (  periph_data_req_o          ),
    .data_add_o_PE      (  periph_data_add_o          ),
    .data_wen_o_PE      (  periph_data_wen_o          ),
    .data_wdata_o_PE    (  periph_data_wdata_o        ),
    .data_be_o_PE       (  periph_data_be_o           ),
    .data_gnt_i_PE      (  periph_data_gnt_i          ),
    .data_r_valid_i_PE  (  periph_data_r_valid_i      ),
    .data_r_rdata_i_PE  (  periph_data_r_rdata_i      ),
    .data_r_opc_i_PE    (  periph_data_r_opc_i        ),

    .perf_l2_ld_o       (  perf_counters[0]           ),
    .perf_l2_st_o       (  perf_counters[1]           ),
    .perf_l2_ld_cyc_o   (  perf_counters[2]           ),
    .perf_l2_st_cyc_o   (  perf_counters[3]           ),
    .CLUSTER_ID         (  cluster_id_i               )
  );

  periph_demux periph_demux_i (
    .clk                ( clk_int                     ),
    .rst_ni             ( rst_ni                      ),

    .data_req_i         ( periph_demux_bus_req        ),
    .data_add_i         ( periph_demux_bus_add        ),
    .data_wen_i         ( periph_demux_bus_wen        ),
    .data_wdata_i       ( periph_demux_bus_wdata      ),
    .data_be_i          ( periph_demux_bus_be         ),
    .data_gnt_o         ( periph_demux_bus_gnt        ),

    .data_r_valid_o     ( periph_demux_bus_r_valid    ),
    .data_r_opc_o       ( periph_demux_bus_r_opc      ),
    .data_r_rdata_o     ( periph_demux_bus_r_rdata    ),

    .data_req_o_MH      ( dma_ctrl_req_o              ),
    .data_add_o_MH      ( dma_ctrl_add_o              ),
    .data_wen_o_MH      ( dma_ctrl_wen_o              ),
    .data_wdata_o_MH    ( dma_ctrl_wdata_o            ),
    .data_be_o_MH       ( dma_ctrl_be_o               ),
    .data_gnt_i_MH      ( dma_ctrl_gnt_i              ),

    .data_r_valid_i_MH  ( dma_ctrl_r_valid_i          ),
    .data_r_rdata_i_MH  ( dma_ctrl_r_rdata_i          ),
    .data_r_opc_i_MH    ( dma_ctrl_r_opc_i            ),

    .data_req_o_EU      ( eu_ctrl_req_o               ),
    .data_add_o_EU      ( eu_ctrl_add_o               ),
    .data_wen_o_EU      ( eu_ctrl_wen_o               ),
    .data_wdata_o_EU    ( eu_ctrl_wdata_o             ),
    .data_be_o_EU       ( eu_ctrl_be_o                ),
    .data_gnt_i_EU      ( eu_ctrl_gnt_i               ),

    .data_r_valid_i_EU  ( eu_ctrl_r_valid_i           ),
    .data_r_rdata_i_EU  ( eu_ctrl_r_rdata_i           ),
    .data_r_opc_i_EU    ( eu_ctrl_r_opc_i             )
  );

endmodule
