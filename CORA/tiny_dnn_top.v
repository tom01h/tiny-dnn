module tiny_dnn_top
  (
    input wire         S_AXI_ACLK,
    input wire         S_AXI_ARESETN,

    ////////////////////////////////////////////////////////////////////////////
    // AXI Lite Slave Interface
    input wire [31:0]  S_AXI_AWADDR,
    input wire         S_AXI_AWVALID,
    output wire        S_AXI_AWREADY,
    input wire [31:0]  S_AXI_WDATA,
    input wire [3:0]   S_AXI_WSTRB,
    input wire         S_AXI_WVALID,
    output wire        S_AXI_WREADY,
    output wire [1:0]  S_AXI_BRESP,
    output wire        S_AXI_BVALID,
    input wire         S_AXI_BREADY,

    input wire [31:0]  S_AXI_ARADDR,
    input wire         S_AXI_ARVALID,
    output wire        S_AXI_ARREADY,
    output wire [31:0] S_AXI_RDATA,
    output wire [1:0]  S_AXI_RRESP,
    output wire        S_AXI_RVALID,
    input wire         S_AXI_RREADY
    );

   reg [3:0]           axist;
   reg [15:2]          wb_adr_i;
   reg [31:16]         wb_dat_i_storage;

   assign S_AXI_BRESP = 2'b00;
   assign S_AXI_RRESP = 2'b00;
   assign S_AXI_AWREADY = (axist == 4'b0000)|(axist == 4'b0010);
   assign S_AXI_WREADY  = (axist == 4'b0000)|(axist == 4'b0001);
   assign S_AXI_ARREADY = (axist == 4'b0000);
   assign S_AXI_BVALID  = (axist == 4'b0011);
   assign S_AXI_RVALID  = (axist == 4'b0100);

   wire [0:15]         busy;

   always @(posedge S_AXI_ACLK)begin
      if(~S_AXI_ARESETN)begin
         axist<=4'b0000;

         wb_adr_i<=0;
         wb_dat_i_storage<=0;
      end else if(axist==4'b000)begin
         if(S_AXI_AWVALID & S_AXI_WVALID)begin
            axist<=4'b00011;
            wb_adr_i[15:2]<=S_AXI_AWADDR[15:2];
            wb_dat_i_storage<=S_AXI_WDATA[31:16];
         end else if(S_AXI_AWVALID)begin
            axist<=4'b0001;
            wb_adr_i[15:2]<=S_AXI_AWADDR[15:2];
         end else if(S_AXI_WVALID)begin
            axist<=4'b0010;
            wb_dat_i_storage<=S_AXI_WDATA[31:16];
         end else if(S_AXI_ARVALID)begin
            if(busy[0:15]==0)
              axist<=4'b0100;
            else
              axist<=4'b1100;
         end
      end else if(axist==4'b0001)begin
         if(S_AXI_WVALID)begin
            axist<=4'b0011;
            wb_dat_i_storage<=S_AXI_WDATA[31:16];
         end
      end else if(axist==4'b0010)begin
         if(S_AXI_AWVALID)begin
            axist<=4'b0011;
            wb_adr_i[15:2]<=S_AXI_AWADDR[15:2];
         end
      end else if(axist==4'b0011)begin
         if(S_AXI_BREADY)
           axist<=4'b0000;
      end else if(axist==4'b0100)begin
         if(S_AXI_RREADY)
           axist<=4'b0000;
      end else if(axist==4'b1100)begin
         if(busy[0:15]==0)
           axist<=4'b0100;
      end
   end



   parameter f_num  = 16;

   wire [12:0] a = (S_AXI_ARVALID & (busy[0:15]==0)) ? S_AXI_ARADDR[14:2] : wb_adr_i[14:2];

   wire        readw = S_AXI_ARVALID & S_AXI_ARREADY & (busy[0:15]==0) & (S_AXI_ARADDR[15]==1'b0);
   wire        nrmen = S_AXI_ARVALID & S_AXI_ARREADY & (busy[0:15]==0) & (S_AXI_ARADDR[15]==1'b1);
   wire        write = (axist==4'b0011) & S_AXI_BREADY & (wb_adr_i[15]==1'b0);
   wire        init  = (axist==4'b0011) & S_AXI_BREADY & ({wb_adr_i[15:2],2'b00}==16'hfffc);
   wire        exec  = (axist==4'b0011) & S_AXI_BREADY & (wb_adr_i[15:11]==5'h10);
   
   wire               signo [0:15];
   wire signed [9:0]  expo [0:15];
   wire signed [31:0] addo [0:15];

   wire [31:0]        nrm;
   wire [15:0]        w [0:15];

   reg                read_l;
   reg [3:0]          a_l;
   
   always @(posedge S_AXI_ACLK)begin
      if(~S_AXI_ARESETN)begin
         a_l <= 4'h0;
      end else if(S_AXI_RREADY)begin
         read_l <= readw;
         if(readw)
           a_l <= a[12:9];
      end
   end

   assign S_AXI_RDATA = (read_l) ? {16'h0,w[a_l]} : nrm;

   normalize normalize
     (
      .clk(S_AXI_ACLK),
      .en(nrmen),
      .signo(signo[S_AXI_ARADDR[5:2]]),
      .expo(expo[S_AXI_ARADDR[5:2]]),
      .addo(addo[S_AXI_ARADDR[5:2]]),
      .nrm(nrm)
   );

   generate
      genvar i;
      for (i = 0; i < f_num; i = i + 1) begin
         tiny_dnn_core tiny_dnn_core
               (
                .clk(S_AXI_ACLK),
                .write(write&(a[12:9] == i)),
                .read(readw&(a[12:9] == i)),
                .init(init),
                .exec(exec),
                .a(a[8:0]),
                .d(wb_dat_i_storage[31:16]),
                .busy(busy[i]),
                .w(w[i]),
                .signo(signo[i]),
                .expo(expo[i]),
                .addo(addo[i])
                );
      end
   endgenerate

endmodule
