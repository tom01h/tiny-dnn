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
   input wire         S_AXI_RREADY,

   input wire         AXIS_ACLK,
   input wire         AXIS_ARESETN,

   ////////////////////////////////////////////////////////////////////////////
   // AXI Stream Master Interface
   output wire        M_AXIS_TVALID,
   output wire [31:0] M_AXIS_TDATA,
   output wire [3:0]  M_AXIS_TSTRB,
   output wire        M_AXIS_TLAST,
   input wire         M_AXIS_TREADY,

   ////////////////////////////////////////////////////////////////////////////
   // AXI Stream Slave Interface
   output wire        S_AXIS_TREADY,
   input wire [31:0]  S_AXIS_TDATA,
   input wire [3:0]   S_AXIS_TSTRB,
   input wire         S_AXIS_TLAST,
   input wire         S_AXIS_TVALID
   );

   parameter f_num  = 16;

   wire               clk = AXIS_ACLK;

   wire               src_ready;
   wire [31:0]        dst_data;
   wire               dst_valid;

   wire               src_valid = S_AXIS_TVALID;
   wire [31:0]        src_data  = S_AXIS_TDATA;
   wire               src_last  = S_AXIS_TLAST;
   assign             S_AXIS_TREADY = src_ready;

   assign             M_AXIS_TVALID = dst_valid;
   assign             M_AXIS_TDATA  = dst_data;
   assign             M_AXIS_TSTRB  = {4{dst_valid}};
// assign             M_AXIS_TLAST  = dst_last;
   assign             M_AXIS_TLAST  = 1'b0;
   wire               dst_ready = M_AXIS_TREADY;


   wire               backprop;
   wire               enbias;
   wire               run;
   wire               wwrite;
   wire               bwrite;

   wire [11:0]        ss;
   wire [3:0]         id;
   wire [9:0]         is;
   wire [4:0]         ih;
   wire [4:0]         iw;
   wire [11:0]        ds;
   wire [3:0]         od;
   wire [9:0]         os;
   wire [4:0]         oh;
   wire [4:0]         ow;
   wire [9:0]         fs;
   wire [9:0]         ks;
   wire [4:0]         kh;
   wire [4:0]         kw;


   tiny_dnn_reg tiny_dnn_reg
     (
      .S_AXI_ACLK(S_AXI_ACLK),
      .S_AXI_ARESETN(S_AXI_ARESETN),

      .S_AXI_AWADDR(S_AXI_AWADDR),
      .S_AXI_AWVALID(S_AXI_AWVALID),
      .S_AXI_AWREADY(S_AXI_AWREADY),
      .S_AXI_WDATA(S_AXI_WDATA),
      .S_AXI_WSTRB(S_AXI_WSTRB),
      .S_AXI_WVALID(S_AXI_WVALID),
      .S_AXI_WREADY(S_AXI_WREADY),
      .S_AXI_BRESP(S_AXI_BRESP),
      .S_AXI_BVALID(S_AXI_BVALID),
      .S_AXI_BREADY(S_AXI_BREADY),

      .S_AXI_ARADDR(S_AXI_ARADDR),
      .S_AXI_ARVALID(S_AXI_ARVALID),
      .S_AXI_ARREADY(S_AXI_ARREADY),
      .S_AXI_RDATA(S_AXI_RDATA),
      .S_AXI_RRESP(S_AXI_RRESP),
      .S_AXI_RVALID(S_AXI_RVALID),
      .S_AXI_RREADY(S_AXI_RREADY),

      .backprop(backprop), .enbias(enbias), 
      .run(run), .wwrite(wwrite), .bwrite(bwrite),
      .ss(ss), .id(id), .is(is), .ih(ih), .iw(iw),
      .ds(ds), .od(od), .os(os), .oh(oh), .ow(ow),
      .fs(fs),          .ks(ks), .kh(kh), .kw(kw)
      );

   //  batch control <-> sample control
   wire               s_init;
   wire               s_fin;

   // sample control -> core
   wire               k_init;
   wire               k_fin;
   wire [3:0]         kn;
   wire [9:0]         wa;
   wire [3:0]         ra;

   // sample control -> core, src buffer
   wire               exec;
   wire [11:0]        ia;
   // sample control -> core, dst buffer
   wire               outr;
   wire [11:0]        oa;

   // batch control -> src buffer
   wire               src_v;
   wire [11:0]        src_a;
   // batch control -> dst buffer
   wire               dst_v;
   wire [11:0]        dst_a;

   // core <-> src,dst buffer
   wire [15:0]        d;
   wire [31:0]        x;

   batch_ctrl batch_ctrl
     (
      .clk(clk),
      .s_init(s_init),
      .s_fin(s_fin),
      .run(run),
      .src_valid(src_valid),
      .src_last(src_last),
      .src_ready(src_ready),
      .src_v(src_v),
      .src_a(src_a[11:0]),
      .dst_valid(dst_valid),
      .dst_ready(dst_ready),
      .dst_v(dst_v),
      .dst_a(dst_a[11:0]),
      .ss(ss[11:0]),
      .ds(ds[11:0])
      );

   src_buf src_buf
     (
      .clk(clk),
      .src_v(src_v),
      .src_a(src_a[11:0]),
      .src_d(src_data[31:16]),
      .exec(exec|k_init),
      .ia(ia[11:0]),
      .d(d)
      );

   dst_buf dst_buf
     (
      .clk(clk),
      .dst_v(dst_v),
      .dst_a(dst_a[11:0]),
      .dst_d(dst_data),
      .outr(outr),
      .oa(oa[11:0]),
      .x(x)
      );

   sample_ctrl sample_ctrl
     (
      .clk(clk),
      .src_valid(src_valid),
      .src_ready(src_ready),
      .backprop(backprop),
      .run(run),
      .wwrite(wwrite),
      .bwrite(bwrite),
      .s_init(s_init),
      .s_fin(s_fin),
      .k_init(k_init),
      .k_fin(k_fin),
      .exec(exec),
      .ia(ia[11:0]),
      .outr(outr),
      .oa(oa[11:0]),
      .kn(kn[3:0]),
      .wa(wa[9:0]),
      .ra(ra[3:0]),
      .id(id[3:0]),
      .is(is[9:0]),
      .ih(ih[4:0]),
      .iw(iw[4:0]),
      .od(od[3:0]),
      .os(os[9:0]),
      .oh(oh[4:0]),
      .ow(ow[4:0]),
      .fs(fs[9:0]),
      .ks(ks[9:0]),
      .kh(kh[4:0]),
      .kw(kw[4:0])
      );

   wire               signo [0:15];
   wire signed [9:0]  expo [0:15];
   wire signed [31:0] addo [0:15];
   wire [31:0]        nrm;

   assign x = nrm;

   normalize normalize
     (
      .clk(clk),
      .en(outr),
      .signo(signo[ra]),
      .expo(expo[ra]),
      .addo(addo[ra]),
      .nrm(nrm)
      );

   generate
      genvar i;
      for (i = 0; i < f_num; i = i + 1) begin
         tiny_dnn_core tiny_dnn_core
               (
                .clk(clk),
                .init(k_init),
                .write((wwrite|bwrite)&(kn[3:0] == i) & src_valid & src_ready),
                .bwrite(bwrite),
                .exec(exec),
                .bias(k_fin&enbias),
                .a(wa[9:0]),
                .d(d),
                .wd(src_data[31:16]),
                .signo(signo[i]),
                .expo(expo[i]),
                .addo(addo[i])
                );
      end
   endgenerate

endmodule
