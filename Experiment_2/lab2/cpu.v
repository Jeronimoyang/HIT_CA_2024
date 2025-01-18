module cpu(
    input           clk,                // ??????
    input           resetn,             // ???????????????

    output          inst_sram_en,       // ????????????
    output[31:0]    inst_sram_addr,     // ????????????
    input[31:0]     inst_sram_rdata,    // ?????????????????

    output          data_sram_en,       // ????????????/??????
    output[3:0]     data_sram_wen,      // ?????????????
    output[31:0]    data_sram_addr,     // ??????????/???????
    output[31:0]    data_sram_wdata,    // ??????????????????
    input[31:0]     data_sram_rdata,    // ??????????????????

    // ????????????????CPU?????????
    output[31:0]    debug_wb_pc,        // ??????????????PC
    output          debug_wb_rf_wen,    // ??????????????????????
    output[4:0]     debug_wb_rf_wnum,   // ?????????????????????????
    output[31:0]    debug_wb_rf_wdata   // ???????????????????
);

    // ========== ?????? ==========
    reg[31:0] PC;
    reg[31:0] IR;

    initial begin
        PC = 0;
        IR = 0;
    end
    // ==============================

    // ========== IF_ID =============
    reg[31:0] IF_ID_PC;
    
    wire[31:0] IF_ID_IR;

    reg[31:0] debug_IF_ID_PC;       // ???????
    // ==============================

    // ========== ID_EX =============
    reg[31:0] ID_EX_PC;
    reg[31:0] ID_EX_IR;
    reg[31:0] ID_EX_R1;
    reg[31:0] ID_EX_R2;
    reg[31:0] ID_EX_IM;

    reg[31:0] debug_ID_EX_PC;       // ???????
    // ==============================

    // ========== EX_MEM ============
    reg[31:0] EX_MEM_RS;
    reg[31:0] EX_MEM_RG;
    reg[31:0] EX_MEM_IR;
    reg EX_MEM_JP;

    reg[31:0] debug_EX_MEM_PC;      // ???????
    // ==============================

    // ========== MEM_WB ============
    reg[31:0] MEM_WB_RS;
    reg[31:0] MEM_WB_IR;
    wire[31:0] MEM_WB_MM;
    reg resetmy;
    reg[31:0] debug_MEM_WB_PC;      // ???????
    // ==============================

    // ========== conflict===========
    wire stall;
    wire sig1_ex_mem_rs;
    wire sig1_mem_wb_mm;
    wire sig1_mem_wb_rs;
    wire sig2_ex_mem_rs;
    wire sig2_mem_wb_mm;
    wire sig2_mem_wb_rs;
    wire test_result;
    // ==============================
      assign debug_wb_pc = debug_MEM_WB_PC;   // ??????? PC ???
    assign debug_wb_rf_wen   = we;          // ???????
    assign debug_wb_rf_wnum  = waddr;       // ??????
    assign debug_wb_rf_wdata = wdata;       // ????????

    // ============ IF ==============
    assign inst_sram_en   = !stall && resetn;
    assign inst_sram_addr = PC;

    wire[31:0] nPC;
    
    wire[31:0] mux0_result;

    // MUX IF_MUX(
    //     .d0        (PC + 4),
    //     .d1     (EX_MEM_RS),
    //     .select (EX_MEM_JP),
    //     .out    (mux0_result)
    // );  // EX_MEM.JP ? EX_MEM_RS : PC + 4

    // assign nPC = mux0_result;

    assign IF_ID_IR = inst_sram_rdata;//??????????


    //////////////////////PREDICTOR////////////////////////
    `timescale 1ns / 1ps
wire  predict_jump;
reg IF_ID_predict_jump;
reg ID_EX_PREDICT_JUMP;
reg EX_MEM_pred_jump;
wire upd_jumpinst;
assign upd_jumpinst = (EX_MEM_IR[31:26] == 6'b000010 || EX_MEM_IR[31:26] == 6'b111111) ? 1'b1 : 1'b0;

wire [31:0] upd_addr;
assign upd_addr = debug_EX_MEM_PC;

reg upd_predfail; // ?????? reg ????
reg upd_predfail_reg; // ?????? reg ????
always @(*) begin
    if (test_result == 1'b1) begin
        if (ID_EX_PREDICT_JUMP == 1'b1 && (ID_EX_IR[31:26] == 6'b000010 || ID_EX_IR[31:26] == 6'b111111)) begin
            upd_predfail_reg = 1'b0;
        end else begin
            upd_predfail_reg = 1'b1;
        end
    end else begin
        // ?? test_result ? 0?????????????? 1 ???????? 1
        if (ID_EX_PREDICT_JUMP == 1'b1) begin
            upd_predfail_reg = 1'b1;
        end else begin
            upd_predfail_reg = 1'b0;
        end
    end
end


always @(posedge clk) begin
    upd_predfail <= upd_predfail_reg;
end

jy_branch_predictor branch_predictor_u(
    .clk(clk),
    .resetn(resetn),
    .old_PC(PC),
    .predict_en(!stall),//
    .new_PC(nPC),
    .predict_jump(predict_jump),
    .upd_en(upd_jumpinst),
    .upd_addr(upd_addr),
    .upd_jumpinst(upd_jumpinst),
    .upd_jump(EX_MEM_JP),
    .upd_predfail(upd_predfail),
    .upd_target(EX_MEM_RS),
    .failed_ir(EX_MEM_IR),
    .failed_pc(debug_EX_MEM_PC)
);

    wire [31:0] edge_counter1;
    wire [31:0] edge_counter2;

    my_edge_counter edge_counter_u0(
        .clk(clk),
        .signal(predict_jump),
        .edge_count(edge_counter1)
    );

    my_edge_counter edge_counter_u1(
        .clk(clk),
        .signal(upd_prefail),
        .edge_count(edge_counter2)
    );

    always @(posedge clk) begin
        if(!stall) begin
            PC       <= {32{resetn}} & nPC;
            IF_ID_PC <= {32{resetn}} & nPC;

            debug_IF_ID_PC <= {32{resetn}} & PC;
            IF_ID_predict_jump <= {32{resetn}} & predict_jump;
        end
    end
    // ==============================

    // ============ ID ==============
    
    conflict conflict(  // ??????????????????????
        .IR1( IF_ID_IR),
        .IR2( ID_EX_IR),
        .IR3(EX_MEM_IR),
        .IR4(MEM_WB_IR),
        .stall(stall),
        .sig1_ex_mem_rs(sig1_ex_mem_rs),
        .sig1_mem_wb_rs(sig1_mem_wb_rs),
        .sig1_mem_wb_mm(sig1_mem_wb_mm),
        .sig2_ex_mem_rs(sig2_ex_mem_rs),
        .sig2_mem_wb_rs(sig2_mem_wb_rs),
        .sig2_mem_wb_mm(sig2_mem_wb_mm)
    );

    wire          we;   // ???????????????????????
    wire[ 5:0] waddr;   // ??????????????
    wire[31:0] wdata;   // ??????????????

    wire[31:0] regfile_rdata1;
    wire[31:0] regfile_rdata2;

    register reg_U(
        .clk   (clk),
        .we    (we),
        .raddr1(IF_ID_IR[25:21]),
        .raddr2(IF_ID_IR[20:16]),
        .waddr (waddr),
        .wdata (wdata),
        .rdata1(regfile_rdata1),
        .rdata2(regfile_rdata2)
    );
    // ????????????????? ID_EX.R1 ??? ID_EX.R2 ???

    wire[31:0] extend_imm;
    my_extend my_extend(
        .A     (IF_ID_IR[15: 0]),   // ??? 16 ???????????
        .B     (extend_imm)
    );
    reg [1:0] test_result_counter;  // 2-bit counter to track 3 cycles (0, 1, 2)

always @(posedge clk) begin
    // Reset and update PC values
    ID_EX_PC <= {32{resetn}} & IF_ID_PC;
    debug_ID_EX_PC <= {32{resetn}} & debug_IF_ID_PC;
    ID_EX_PREDICT_JUMP <= {32{resetn}} & IF_ID_predict_jump;
    if (resetn == 0) begin
        test_result_counter <= 0;  // Reset counter on system reset
    end

    if (stall) begin
        // Stall the pipeline, clear the relevant registers
        ID_EX_IR <= 0;
        ID_EX_R1 <= 0;
        ID_EX_R2 <= 0;
        ID_EX_IM <= 0;
    end 
    else if ( upd_predfail_reg|| test_result_counter > 0) begin
        // Handle test_result condition: clear IR registers for 3 cycles
        ID_EX_IR <= 0;
        EX_MEM_IR <= 0;
        MEM_WB_IR <= 0;
        IF_ID_predict_jump <= 0;
        ID_EX_PREDICT_JUMP <= 0;
        EX_MEM_pred_jump <= 0;
        resetmy <= 0;
        
        // Increment the counter each cycle while test_result_counter < 3
        if (test_result_counter < 2) begin
            test_result_counter <= test_result_counter + 1;
        end else begin
            // After 3 cycles, reset the counter and restore normal operation
            test_result_counter <= 0;
            resetmy <= 1;  // Restore resetmy signal after 3 cycles
        end
    end 
    else begin
        // Normal operation: update registers
        ID_EX_R1 <= {32{resetn}} & regfile_rdata1;
        ID_EX_R2 <= {32{resetn}} & regfile_rdata2;
        ID_EX_IR <= {32{resetn}} & IF_ID_IR;
        ID_EX_IM <= {32{resetn}} & extend_imm;
        resetmy <= 1;
    end

    // Jump condition: clear ID_EX_IR
    /*if (EX_MEM_JP) begin
        ID_EX_IR <= 0;
    end */
end

  



    // ==============================

    // ============ EX ==============
    wire[31:0] alu_a, reg_a;
    wire[31:0] alu_b, reg_b;

    cond_mux cond_mux_1(
        .sig_ex_mem_rs(sig1_ex_mem_rs),
        .sig_mem_wb_rs(sig1_mem_wb_rs),
        .sig_mem_wb_mm(sig1_mem_wb_mm),
        .ex_mem_rs(EX_MEM_RS),
        .mem_wb_rs(MEM_WB_RS),
        .mem_wb_mm(MEM_WB_MM),
        .id_ex_r1(ID_EX_R1),
        .r1(reg_a)
    );  // ??? ID_EX.R1 ???????????????
    cond_mux cond_mux_2(
        .sig_ex_mem_rs(sig2_ex_mem_rs),
        .sig_mem_wb_rs(sig2_mem_wb_rs),
        .sig_mem_wb_mm(sig2_mem_wb_mm),
        .ex_mem_rs(EX_MEM_RS),
        .mem_wb_rs(MEM_WB_RS),
        .mem_wb_mm(MEM_WB_MM),
        .id_ex_r1(ID_EX_R2),
        .r1(reg_b)
    );  // ??? ID_EX.R2 ???????????????

    wire mux1_select, mux2_select;

    MUX EX_MUX1(
        .d0(ID_EX_PC),
        .d1(reg_a),
        .select(mux1_select),
        .out(alu_a)
    );  // ??? PC ??? R1 ?????????
    assign mux1_select =
        (ID_EX_IR[31:26] == 6'b000000) |    // ????????????? R1
        (ID_EX_IR[31:26] == 6'b101011) |    // ????????????? R1
        (ID_EX_IR[31:26] == 6'b100011) |    // ???????????? R1
        (ID_EX_IR[31:26] == 6'b111110) |    // ???????????? R1
        (ID_EX_IR[31:26] == 6'b111111);     // ????????????? R1

    MUX EX_MUX2(
        .d0(ID_EX_IM),
        .d1(reg_b),
        .select(mux2_select),
        .out(alu_b)
    );  // ??? R2 ??? IM ?????????
    assign mux2_select =
        (ID_EX_IR[31:26] == 6'b000000) |    // ????????????? R2
        (ID_EX_IR[31:26] == 6'b111110);     // ???????????? R2

    wire[31:0] alu_result;
    wire[ 5:0] alu_card = 
        ({6{ID_EX_IR[31:26] == 6'b000000}} & ID_EX_IR[5:0]) |   // ?????????????????????
        ({6{ID_EX_IR[31:26] == 6'b111110}} & 6'b111110)     |   // ????????????????????
        ({6{ID_EX_IR[31:26] == 6'b101011}} & 6'b100000)     |   // ??????????????
        ({6{ID_EX_IR[31:26] == 6'b100011}} & 6'b100000);        // ?????????????
    ALU EX_ALU(      // ????????????????
        .A(alu_a),
        .B(alu_b),
        .F(alu_result),
        .Shft(ID_EX_IR[10: 6]),
        .Card(alu_card)
    );

    
    ZERO zero_u(    // ???????
        .R1(reg_a),
        .R2(reg_b),
        .IR(ID_EX_IR),
        .J(test_result)
    );

    always @(posedge clk) begin
        EX_MEM_RG <= {32{resetn}} & reg_b ;
        EX_MEM_pred_jump<= {32{resetn}} & ID_EX_PREDICT_JUMP;
        EX_MEM_IR <= {32{resetn}} & {32{resetmy}}& (
            {32{!(ID_EX_IR[31:26] == 6'b000000 && ID_EX_IR[5:0] == 6'b001010 && reg_b != 0)}}
        ) & ID_EX_IR;
            // ?????? MOVZ ????? R2 ??? 0 ??????????
        EX_MEM_RS <= {32{resetn}} & (
            ({32{ID_EX_IR[31:26] == 6'b000000}} & alu_result) |  // ?????????? ALU
            ({32{ID_EX_IR[31:26] == 6'b100011}} & alu_result) |  // ????????? ALU
            ({32{ID_EX_IR[31:26] == 6'b101011}} & alu_result) |  // ?????????? ALU
            ({32{ID_EX_IR[31:26] == 6'b111110}} & alu_result) |  // ????????? ALU
            ({32{ID_EX_IR[31:26] == 6'b000010}} & { ID_EX_PC[31:28], ID_EX_IR[25:0], 2'b00 }) |   // ?????????????
            ({32{ID_EX_IR[31:26] == 6'b111111}} & (ID_EX_PC + {{14{ID_EX_IR[15]}}, ID_EX_IR[15:0], 2'b00}))
        );
        EX_MEM_JP <= resetn & test_result;
        debug_EX_MEM_PC <= {32{resetn}} & debug_ID_EX_PC;
    end
    // ==============================

    // =========== MEM ==============
    assign data_sram_addr  = EX_MEM_RS;     // ????????????????
    assign data_sram_wdata = EX_MEM_RG;     // ???????????????
    assign data_sram_wen   = EX_MEM_IR[31:26] == 6'b101011;     // ??????????????
    assign data_sram_en    =
        (EX_MEM_IR[31:26] == 6'b100011) |       // ????????
        (EX_MEM_IR[31:26] == 6'b101011);        // ?????????
    
    assign MEM_WB_MM = {32{resetn}} & data_sram_rdata;
    // ????????????????? SRAM ???????????
        
    always @(posedge clk) begin
        MEM_WB_IR <= {32{resetn}} & EX_MEM_IR;
        MEM_WB_RS <= {32{resetn}} & EX_MEM_RS;
        
        debug_MEM_WB_PC <= {32{resetn}} & {32{resetmy}}& debug_EX_MEM_PC;
    end
    // ==============================

    // ============ WB ==============
    wire mux3_select;

    MUX WB_MUX(
        .d0(MEM_WB_RS),         // ???????
        .d1(MEM_WB_MM),         // ???????
        .select(mux3_select),
        .out(wdata)
    );
    assign waddr =
        ({32{MEM_WB_IR[31:26] == 6'b100011}} & MEM_WB_IR[20:16]) |  // ?????????? IR[20:16]
        ({32{MEM_WB_IR[31:26] == 6'b000000}} & MEM_WB_IR[15:11]) |  // ??????????? IR[15:11]
        ({32{MEM_WB_IR[31:26] == 6'b111110}} & MEM_WB_IR[15:11]);   // ?????????? IR[15:11]
    assign mux3_select =
        (MEM_WB_IR[31:26] == 6'b100011);        // ?????????????????
    assign we =
        ((MEM_WB_IR[31:26] == 6'b000000) |      // ?????????????
         (MEM_WB_IR[31:26] == 6'b100011) |      // ????????????
         (MEM_WB_IR[31:26] == 6'b111110) ) &    // ????????????
        (waddr != 0);                           // ???????? r0 ??????
    // ==============================

  
endmodule