// tb_generic_rom.sv - check rtl/generic_rom.sv against boot_code.cde
// Reads every one of the 2048 addresses and compares with the .cde file.
//
// Run from asic/pulp_soc:
//   vlib work_rom
//   vlog -work work_rom -sv rtl/generic_rom.sv scripts/tb_generic_rom.sv
//   vsim -work work_rom -c tb_generic_rom -do "run -all; quit"
//   rm -rf work_rom
// Expected: "PASS: 2048 addresses match"
module tb_generic_rom;
  localparam int AW = 11;
  localparam int DW = 32;
  localparam string CDE = "../../sim/boot/boot_code.cde";

  logic          clk = 1'b0;
  logic          cen = 1'b1;
  logic [AW-1:0] a   = '0;
  logic [DW-1:0] q;
  logic [DW-1:0] ref_mem [0:(1<<AW)-1];
  int            errors = 0;

  generic_rom #(.ADDR_WIDTH(AW), .DATA_WIDTH(DW)) dut (.CLK(clk), .CEN(cen), .A(a), .Q(q));

  always #5 clk = ~clk;

  initial begin
    $readmemb(CDE, ref_mem);
    @(negedge clk);
    for (int i = 0; i < (1<<AW); i++) begin
      cen = 1'b0;                    // request
      a   = i[AW-1:0];
      @(negedge clk);                // address registered on the posedge in between
      cen = 1'b1;
      if (q !== ref_mem[i]) begin
        errors++;
        if (errors <= 10) $display("MISMATCH addr %0d: rom=%h cde=%h", i, q, ref_mem[i]);
      end
    end
    if (errors == 0) $display("PASS: %0d addresses match", 1<<AW);
    else             $display("FAIL: %0d mismatches", errors);
    $finish;
  end
endmodule
