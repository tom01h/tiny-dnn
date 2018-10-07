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

   reg [15:0]          ram [0:512*16-1];

   reg [3:0]           axist;
   reg [15:2]          wb_adr_i;
   reg [15:0]          wb_dat_i_storage;
   reg [15:0]          wb_dat_o_i;

   assign S_AXI_BRESP = 2'b00;
   assign S_AXI_RRESP = 2'b00;
   assign S_AXI_AWREADY = (axist == 4'b0000)|(axist == 4'b0010);
   assign S_AXI_WREADY  = (axist == 4'b0000)|(axist == 4'b0001);
   assign S_AXI_ARREADY = (axist == 4'b0000);
   assign S_AXI_BVALID  = (axist == 4'b0011);
   assign S_AXI_RVALID  = (axist == 4'b0100);
   assign S_AXI_RDATA   = {16'h0,wb_dat_o_i};

   always @(posedge S_AXI_ACLK)begin
      if(~S_AXI_ARESETN)begin
         axist<=4'b0000;

         wb_adr_i<=0;
         wb_dat_i_storage<=0;
      end else if(axist==4'b000)begin
         if(S_AXI_AWVALID & S_AXI_WVALID)begin
            axist<=4'b00011;
            wb_adr_i[15:2]<=S_AXI_AWADDR[15:2];
            wb_dat_i_storage<=S_AXI_WDATA[15:0];
         end else if(S_AXI_AWVALID)begin
            axist<=4'b0001;
            wb_adr_i[15:2]<=S_AXI_AWADDR[15:2];
         end else if(S_AXI_WVALID)begin
            axist<=4'b0010;
            wb_dat_i_storage<=S_AXI_WDATA[15:0];
         end else if(S_AXI_ARVALID)begin
            axist<=4'b0100;
         end
      end else if(axist==4'b0001)begin
         if(S_AXI_WVALID)begin
            axist<=4'b0011;
            wb_dat_i_storage<=S_AXI_WDATA[15:0];
         end
      end else if(axist==4'b0010)begin
         if(S_AXI_AWVALID)begin
            axist<=4'b0011;
            wb_adr_i[15:2]<=S_AXI_AWADDR[15:2];
         end
      end else if(axist==4'b0011)begin
         if(S_AXI_BREADY)begin
            axist<=4'b0000;
         end
      end else if(axist==4'b0100)begin
         if(S_AXI_RREADY&S_AXI_RVALID)begin
            axist<=4'b0000;
         end
      end
   end

   reg [15:0] sum;

   always @(posedge S_AXI_ACLK)
     if (S_AXI_ARVALID) begin
        if(S_AXI_ARADDR[15]==1'b0)
          wb_dat_o_i<=ram[S_AXI_ARADDR[14:2]];
        else
          wb_dat_o_i<=sum;
     end

   always @(posedge S_AXI_ACLK)
     if ((axist==4'b0011)&S_AXI_BREADY)begin
        if(wb_adr_i[15]==1'b0)
          ram[wb_adr_i[14:2]]<=S_AXI_WDATA;
        else
          sum<=sum+S_AXI_WDATA*ram[wb_adr_i[14:2]];
     end

endmodule
