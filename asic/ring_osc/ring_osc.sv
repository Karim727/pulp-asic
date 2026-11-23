// Enable-gated, divided Sky130 standard-cell ring oscillator targeting <= 20 MHz
// for pulp_soc (CLOCK_PERIOD = 50 ns on ref_clk_i).
//
// Core loop: 1x nand2_2 + 2x inv_2 + NUM_DLY_STAGES x dlygate4sd3_1 (~0.52 ns/stage @ tt)
// Divider  : DIV_BITS-bit ripple/binary counter -> f_out = f_ring / (2^DIV_BITS)
//
// With NUM_DLY_STAGES=6, DIV_BITS=4 (/16):
//   Raw ring ~148 MHz (tt) / ~220 MHz (ff) -> osc_out ~9.3 MHz (tt) / ~13.8 MHz (ff).

(* keep_hierarchy = "yes" *)
module ring_osc #(
    parameter integer NUM_DLY_STAGES = 6,
    parameter integer DIV_BITS       = 4
)(
`ifdef USE_POWER_PINS
    inout  wire vccd1,
    inout  wire vssd1,
`endif
    input  wire en_i,
    input  wire rst_ni,
    output wire osc_out
);

    (* keep = "true" *) wire ring_nand_out;
    (* keep = "true" *) wire ring_inv0_out;
    (* keep = "true" *) wire ring_inv1_out;
    (* keep = "true" *) wire [NUM_DLY_STAGES:0] dly_chain;
    (* keep = "true" *) wire ring_clk;

    // 1st inversion + enable gate: en_i=0 holds ring_nand_out=1 and halts oscillation
    (* keep = "true" *)
    sky130_fd_sc_hd__nand2_2 u_nand_en (
        .A (en_i),
        .B (dly_chain[NUM_DLY_STAGES]),
        .Y (ring_nand_out)
`ifdef USE_POWER_PINS
        ,.VPWR(vccd1),
        .VGND(vssd1),
        .VPB (vccd1),
        .VNB (vssd1)
`endif
    );

    // 2nd and 3rd inversions (total odd number of inversions = 3)
    (* keep = "true" *)
    sky130_fd_sc_hd__inv_2 u_inv0 (
        .A (ring_nand_out),
        .Y (ring_inv0_out)
`ifdef USE_POWER_PINS
        ,.VPWR(vccd1),
        .VGND(vssd1),
        .VPB (vccd1),
        .VNB (vssd1)
`endif
    );

    (* keep = "true" *)
    sky130_fd_sc_hd__inv_2 u_inv1 (
        .A (ring_inv0_out),
        .Y (ring_inv1_out)
`ifdef USE_POWER_PINS
        ,.VPWR(vccd1),
        .VGND(vssd1),
        .VPB (vccd1),
        .VNB (vssd1)
`endif
    );

    assign dly_chain[0] = ring_inv1_out;

    // Non-inverting delay chain
    genvar i;
    generate
        for (i = 0; i < NUM_DLY_STAGES; i = i + 1) begin : gen_dly
            (* keep = "true" *)
            sky130_fd_sc_hd__dlygate4sd3_1 u_dly (
                .A (dly_chain[i]),
                .X (dly_chain[i + 1])
`ifdef USE_POWER_PINS
                ,.VPWR(vccd1),
                .VGND(vssd1),
                .VPB (vccd1),
                .VNB (vssd1)
`endif
            );
        end
    endgenerate

    // Buffer tap from ring to divider clock input
    (* keep = "true" *)
    sky130_fd_sc_hd__buf_4 u_ring_buf (
        .A (dly_chain[NUM_DLY_STAGES]),
        .X (ring_clk)
`ifdef USE_POWER_PINS
        ,.VPWR(vccd1),
        .VGND(vssd1),
        .VPB (vccd1),
        .VNB (vssd1)
`endif
    );

    // Frequency divider (50% duty cycle MSB)
    logic [DIV_BITS-1:0] div_cnt;
    always_ff @(posedge ring_clk or negedge rst_ni) begin
        if (!rst_ni) begin
            div_cnt <= '0;
        end else begin
            div_cnt <= div_cnt + 1'b1;
        end
    end

    assign osc_out = div_cnt[DIV_BITS-1];

endmodule
