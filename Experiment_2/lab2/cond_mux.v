module cond_mux(
    input sig_ex_mem_rs,
    input sig_mem_wb_rs,
    input sig_mem_wb_mm,
    input [31:0] ex_mem_rs,
    input [31:0] mem_wb_rs,
    input [31:0] mem_wb_mm,
    input [31:0] id_ex_r1,
    output [31:0] r1
);
assign r1 = sig_ex_mem_rs ? ex_mem_rs : sig_mem_wb_rs ? mem_wb_rs : sig_mem_wb_mm ? mem_wb_mm : id_ex_r1;
endmodule