module cache (
    input            clk             ,  // clock, 100MHz
    input            resetn             ,  // active low

    //  Sram-Like接口信号，用于CPU访问Cache
    input         cpu_req      ,    //由CPU发送至Cache，CPU请求信号，表示CPU发起读操作
    input  [31:0] cpu_addr     ,    //由CPU发送至Cache，CPU请求地址
    output reg [31:0] cache_rdata  ,    //由Cache返回给CPU，缓存返回给CPU的数据
    output   reg    cache_addr_ok,    //由Cache返回给CPU，缓存地址确认信号，地址已就绪
    output   reg  cache_data_ok,    //由Cache返回给CPU, 缓存数据确认信号，数据已就绪

    //  AXI接口信号，用于Cache访问主存
    output reg [3 :0] arid   ,              //Cache向主存发起读请求时使用的AXI信道的id号
    output reg [31:0] araddr ,              //Cache向主存发起读请求时所使用的地址
    output   reg     arvalid,              //Cache向主存发起读请求的请求信号
    input         arready,              //读请求能否被接收的握手信号

    input  [3 :0] rid    ,              //主存向Cache返回数据时使用的AXI信道的id号
    input  [31:0] rdata  ,              //主存向Cache返回的数据
    input         rlast  ,              //是否是主存向Cache返回的最后一个数据
    input         rvalid ,              //主存向Cache返回数据时的数据有效信号
    output    reg    rready                //标识当前的Cache已经准备好可以接收主存返回的数据
);

    /*TODO：完成指令Cache的设计代码*/
    reg w_tag_1;    // 双向关联缓存的标签表的写使能信号
    reg w_tag_2;    // 双向关联缓存的标签表的写使能信号
    wire hit_1;     // 指示标签表中的数据是否与请求的数据匹配
    wire hit_2;     // 指示标签表中的数据是否与请求的数据匹配
    reg hit_temp; // 保存hit
    wire [31:0]out_data1;
    wire [31:0]out_data2;
    reg hit; // 确定最终是否命中
    integer i;  // 计数器
    reg data_ok;
    reg miss; // 标记是否缺失
    reg load; // 标记是否正在载入
    reg reset_i; // 重置i信号
    reg [2:0]temp_tr;   // 保存未命中时地址的offset
//    reg rlast_temp; // 保存last数据
    
    // 当前取数地址的寄存器
    reg [31:0] reg_addr;    //当前请求的地址
    reg [19:0] reg_tag    ; //当前请求地址的tag
    reg [6 :0] reg_index  ; //当前请求地址的index
    reg [4 :0] reg_offset ; //当前请求地址的offset
    integer switch;
//    reg [9 :0] write_addr;
//    reg [31:0] write_data_temp;
        
    // 实例化两个tag表
    // 两个标签表分别对应缓存的两个组，addr和tag用于地址和标签匹配
    // we用于写使能，hit用于判断是否命中
    icache_tagv_table tag_table1(
        .clk(clk),
        .resetn(resetn),
        .wen(w_tag_1),
        .valid_wdata(1'b1),
        //        .tag_wdata(reg_tag),
        .tag_wdata(reg_addr[31:12]),
//        .windex(reg_index),
        .windex(reg_addr[11:5]),
        .rden(1),
        .cpu_addr(cpu_addr),
        .hit(hit_1)
    );
    
    icache_tagv_table tag_table2(
        .clk(clk),
        .resetn(resetn),
        .wen(w_tag_2),
        .valid_wdata(1'b1),
//        .tag_wdata(reg_tag),
        .tag_wdata(reg_addr[31:12]),
//        .windex(reg_index),
        .windex(reg_addr[11:5]),
        .rden(1),
        .cpu_addr(cpu_addr),
        .hit(hit_2)
    );
    
    // 实例化两个存储数据的ram
    // 表示两组的数据存储器，用于缓存数据块，wea信号控制写入数据
    //addra表示地址，dina表示写入的数据，addrb表示读取的地址，doutb表示读取的数据
    blk_mem_gen_0 data_1(
        .clka(clk),
        .wea(w_tag_1),
//        .addra(write_addr),
        .addra({reg_addr[11:5], 3'd0} + i),
//        .dina(write_data_temp),
        .dina(rdata),
        .clkb(clk),
        .enb(1'b1),
        .addrb(i == 0 ?  cpu_addr[11:2] : reg_addr[11:2]),
        .doutb(out_data1)
    );
    
    blk_mem_gen_0 data_2(
        .clka(clk),
        .wea(w_tag_2),
//        .addra(write_addr),
        .addra({reg_addr[11:5], 3'd0} + i),
//        .dina(write_data_temp),
        .dina(rdata),
        .clkb(clk),
        .enb(1'b1),
        .addrb(i == 0 ?  cpu_addr[11:2] : reg_addr[11:2]),
        .doutb(out_data2)
    );
    
    // 这个块在 i 改变时触发，判断 temp_tr 和 i 的值
    // 当temp_tr为3'b111且i为7时，将数据返回给CPU
    // 否则，根据w_tag_1和w_tag_2的值，返回对应的数据
    always@(i) begin
        if (temp_tr == 3'b111 && i == 7)  begin
                 assign cache_rdata = rdata;
        end
        else begin
            if (w_tag_1) begin
                assign cache_rdata = out_data1;  
            end   
            else begin
                assign cache_rdata = out_data2;
            end
        end
    end
    
    always@(hit, i, load, miss, posedge clk) begin
        // 当命中时，且i为7或0时，并且没有加载时，设置cache_data_ok和cache_addr_ok为1
        if(hit && (i == 7 || i == 0) && load == 1'b0) begin
            // 如果data_ok为1，说明数据已经准备好，设置cache_data_ok为1
            if (data_ok) begin
                cache_data_ok = 1'b1;
                cache_addr_ok = 1'b1;
        end
           // 否则，设置data_ok为1
           data_ok = 1'b1;
        end
        // 若 i=7 且未命中（hit=0），也设置 cache_data_ok 和 cache_addr_ok 为 1。
        if (i == 7 && hit == 1'b0) begin
            cache_data_ok = 1'b1;
            cache_addr_ok = 1'b1;
//            i = 0;
        end
        // 当加载状态 load=1 时，cache_data_ok 和 cache_addr_ok 置为 0
        else if (load == 1'b1) begin
            cache_data_ok <= 1'b0;
            cache_addr_ok <= 1'b0;
        end
        // 若未命中且复位信号失效，也将 cache_data_ok 和 cache_addr_ok 设置为 0
        else if (hit == 1'b0 && resetn == 1'b1) begin
            cache_data_ok = 1'b0;
            cache_addr_ok = 1'b0;
        end
    end
    
    
    always@(posedge clk, i) begin
    // 如果复位信号有效，将所有信号置为0
    if (!resetn) begin
            cache_data_ok = 1'b0;
            cache_addr_ok = 1'b1;
            arvalid = 1'b0;
            rready = 1'b0;
            i = 0;
            w_tag_1 = 1'b0;
            w_tag_2 = 1'b0;
            miss = 1'b0;
            data_ok = 1'b0;
            load = 1'b0;
            switch = 0;
//            rlast_temp = 1'b0;
        end
        // 否则
    else begin
        // 如果i=7，将写使能信号置为0，重置i
        if (i == 7) begin
             // 关闭写使能
             w_tag_1 <= 1'b0;
             w_tag_2 <= 1'b0;
             reset_i <= 1'b1;
             i = 0;
        end
        // 如果CPU请求信号有效，将CPU地址写入reg_addr
        if (cache_addr_ok) begin
            reg_tag<=cpu_addr[31:12];
            reg_index<=cpu_addr[11:5];
            reg_offset<=cpu_addr[4:0];
            reg_addr<=cpu_addr;
        end
        // hit命中信号为两个tag表的hit信号的或
        assign hit = hit_1 | hit_2;
        hit_temp <= hit_1; // 保存上一周期的hit数据
        // 如果命中，且i为7或0，且未加载，则设置miss为0
        if (hit == 1'b1 && (i == 7 || i == 0) && load == 1'b0) begin  // 保证装填完成后再执行
        miss <= 1'b0;
            // 准备将要返回的数据
            if (hit_temp) begin
                assign cache_rdata = out_data1;  
            end   
            else begin
                assign cache_rdata = out_data2;
            end
        end
        //否则，要阻塞cache
        else begin
            // 阻塞cache
            
            cache_data_ok <= 1'b0;
            cache_addr_ok <= 1'b0;
            miss <= 1'b1;
            load <= 1'b1;
            data_ok = 1'b0;
            
            if (switch % 2) begin
            // 打开写使能
            w_tag_1 <= 1'b1;
            w_tag_2 <= 1'b1;
            end
                     
            // 设置握手信号

            //地址握手阶段，如下图所示，Cache向主存送出欲读数据的地址（araddr），
            //以及一些其它信息（arid，在本实验中置0即可），通过拉高arvalid表示读请求。
            //若某个时钟上升沿时，arvalid和arready同时为高，则握手成功，主存接受了地址，开始准备数据。
            //此时Cache必须拉低arvalid信号，否则可能会重复握手导致错误

            //数据握手阶段，如下图所示，当Cache准备好接收数据字时，将rready拉高，
            //当主存向Cache通过rdata传送一个数据字时，将rvalid拉高。
            //若某个时钟上升沿时，rvalid和rready同时拉高，则握手成功，Cache成功接收了一个数据字。
            //在本实验中，一次AXI传输固定为8个数据字，也就是说需要握手8次（一般是连续的8个周期，但也不一定），
            //在传送最后一个数据字时，主存会将rlast拉高，表示这是最后一个。
            arid <= 3'b000;
            assign araddr = {reg_addr[31:5], 5'd0};
            arvalid <= 1'b1;
            if (arready == 1'b0) begin
                rready <= 1'b1;
                arvalid <= 1'b0;
                if (rvalid) begin
//                write_data_temp <= rdata;
//                rlast_temp <= rlast;
                    if (!rlast) begin
                          // 更新将要写入的addr
//                        write_addr <= {cpu_addr[11:5], 3'd0} + i;
                        i = i+1;
                    end
                    else begin
                        rready = 1'b0;
                    end
                    
                end
            end 
        end
    end
    end
    // rlast 是一个信号，通常在总线协议（如 AXI 协议）中表示“读数据传输的最后一拍”。
    //也就是说，当 rlast 为高电平时，表示数据传输的最后一批数据已经到达
    //当 rlast 触发时，i 被设置为 7，这与之前的代码保持一致，
    //即在 i == 7 的时候数据已准备好，可以从 rdata 中读取
    //load 被置为 1'b0，表明缓存操作已完成，不再需要加载更多数据
    always@(rlast) begin
        if (rlast) begin
            i = 7;
            load = 1'b0;
        end
    end
    //cache_data_ok 表示缓存数据是否准备好
    //在 hit == 1'b0 和 i != 7 的条件下，temp_tr 会被设置为 cpu_addr[4:2] 的值
    //当缓存未命中且 i 还未达到结束状态时，temp_tr 会被设置为 cpu_addr[4:2] 的值，用于后续的加载操作
    always@(cache_data_ok) begin
        if(hit == 1'b0 && i != 7) begin
            temp_tr = cpu_addr[4:2];
        end
    end
    //每个时钟周期 switch 增加 1，用于周期性地改变一些状态，可能控制缓存数据的切换或刷新
    always@(posedge clk) begin
        switch = switch + 1;
    end
    

endmodule