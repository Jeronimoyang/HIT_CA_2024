module jy_branch_predictor(
    input           clk,        //时钟信号，必须与CPU保持�?�?
    input           resetn,     //低有效复位信号，必须与CPU保持�?�?

    //供CPU第一级流水段使用的接口：
    input[31:0]     old_PC,     //上一个指令地�?

    input           predict_en,     //这周期是否需要更新PC（进行分支预测）

    output[31:0]    new_PC,     //预测出的下一个指令地�?

    output          predict_jump,       //是否被预测为执行转移的转移指�?

    //分支预测器更新接口：
    //更新使能
    input           upd_en,
    //转移指令地址
    input[31:0]     upd_addr,
    //是否为转移指�?
    input           upd_jumpinst,
    //若为转移指令，则是否转移
    input           upd_jump,//应该转移�?
    //是否预测失败
    input           upd_predfail,
    //转移指令本身的目标地�?（无论是否转移）
    input[31:0]     upd_target,
    input[31:0]     failed_pc,
    input[31:0]    failed_ir
   
);

    reg [65:0]BTB[63:0];    //创建�?个根据PC[7:2]寻址的BTB表项，相当于直接映射后续寻找只需要对比一个项就可�?
    integer i;
    
    initial begin
    for (i = 0; i < 64; i = i + 1) begin
      BTB[i] = 66'h0;            //必须全部初始化，不能存在XXXXX，否则最后assign赋�?�会赋�?�失�?
    end
    for(i=0;i<64;i=i+1) begin
      BTB[i][1:0]=2'b11;        //将BPB两位初始化为11
    end

    end
    wire [31:0] rec_target;
    assign rec_target=({32{failed_ir[31:26] == 6'b000010}} & { 32'd4+failed_pc[31:28], failed_ir[25:0], 2'b00 }) |   // 无条件跳转指�??
            ({32{failed_ir[31:26] == 6'b111111}} & (failed_pc + 32'd4+{{14{failed_ir[15]}}, failed_ir[15:0], 2'b00}));
    /*为BTB赋�?�，BTB初始时没有任何信息，之后随着upd反馈来添加转移指令以及转移目�?*/
    always @(posedge clk) begin
    if(upd_en==1'b1&&upd_jumpinst==1'b1&&BTB[upd_addr[7:2]][33:2]==32'h0) begin  //只有在指定位置全�?0才能进行赋�?�，不是0代表已经存在指令
    BTB[upd_addr[7:2]][33:2]=upd_addr;    //存储转移PC
    BTB[upd_addr[7:2]][65:34]=upd_target;  //存储目的PC
    end
    end
    
    always @(upd_en) begin          //根据转移结果调整两位BPB
    if(upd_jumpinst==1'b1&&upd_en==1'b1&&upd_addr==BTB[upd_addr[7:2]]) begin  //更新条件
    
    if(upd_predfail==1'b1) begin   //预测失败而更�?
    
    if(BTB[upd_addr[7:2]][1:0]==2'b00) begin
    BTB[upd_addr[7:2]][1:0]<=2'b00;
    end
    else if(BTB[upd_addr[7:2]][1:0]==2'b01) begin
    BTB[upd_addr[7:2]][1:0]<=2'b00;
    end
    else if(BTB[upd_addr[7:2]][1:0]==2'b10) begin
    BTB[upd_addr[7:2]][1:0]<=2'b00;
    end
    else if(BTB[upd_addr[7:2]][1:0]==2'b11) begin
    BTB[upd_addr[7:2]][1:0]<=2'b10;
    end
    
    end
    
    else if(upd_predfail==1'b0) begin   //预测成功而更�?
    
    if(BTB[upd_addr[7:2]][1:0]==2'b00) begin
    BTB[upd_addr[7:2]][1:0]<=2'b01;
    end
    else if(BTB[upd_addr[7:2]][1:0]==2'b01) begin
    BTB[upd_addr[7:2]][1:0]<=2'b11;
    end
    else if(BTB[upd_addr[7:2]][1:0]==2'b10) begin
    BTB[upd_addr[7:2]][1:0]<=2'b11;
    end
    else if(BTB[upd_addr[7:2]][1:0]==2'b11) begin
    BTB[upd_addr[7:2]][1:0]<=2'b11;
    end
    
    end
    
    end
    end
    //预测�?�?
    assign new_PC = (upd_predfail) ? 
                    (upd_jump ? rec_target : (failed_pc +4)) : 
                    (old_PC != 32'b0 && old_PC == BTB[old_PC[7:2]][33:2] && predict_en == 1'b1 && 
                     (BTB[old_PC[7:2]][1:0] == 2'b10 || BTB[old_PC[7:2]][1:0] == 2'b11)) ? 
                     BTB[old_PC[7:2]][65:34] : 
                     (old_PC + 4);
    assign predict_jump=(old_PC!=32'b0&&old_PC==BTB[old_PC[7:2]][33:2]&&predict_en==1'b1&&(BTB[old_PC[7:2]][1:0]==2'b10||BTB[old_PC[7:2]][1:0]==2'b11))? 1'b1:1'b0;
    

endmodule
    // ==============================