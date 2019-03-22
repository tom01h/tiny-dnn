module tiny_dnn_top
  (
   input wire         clk,

   input wire         backprop,
   input wire         enbias,
   input wire         run,
   input wire         wwrite,
   input wire         bwrite,

   output wire        s_init,
   input wire         s_fin,
   input wire         k_init,
   input wire         k_fin,
   input wire         exec,
   input wire [12:0]  ia/*verilator sc_bv*/,
   input wire         outr,
   input wire [12:0]  oa/*verilator sc_bv*/,
   input wire [3:0]   kn/*verilator sc_bv*/,
   input wire [9:0]   wa/*verilator sc_bv*/,
   input wire [3:0]   ra/*verilator sc_bv*/,
   input wire [9:0]   prm_a/*verilator sc_bv*/,

   input wire         src_valid,
   input wire [31:0]  src_data,
   input wire         src_last,
   output wire        src_ready,

   output wire        dst_valid,
   output wire [31:0] dst_data,
   output wire        dst_last,
   input wire         dst_ready,

   input wire [11:0]  ss/*verilator sc_bv*/,
   input wire [3:0]   id/*verilator sc_bv*/,
   input wire [9:0]   is/*verilator sc_bv*/,
   input wire [4:0]   ih/*verilator sc_bv*/,
   input wire [4:0]   iw/*verilator sc_bv*/,
   input wire [11:0]  ds/*verilator sc_bv*/,
   input wire [3:0]   od/*verilator sc_bv*/,
   input wire [9:0]   os/*verilator sc_bv*/,
   input wire [4:0]   oh/*verilator sc_bv*/,
   input wire [4:0]   ow/*verilator sc_bv*/,
   input wire [9:0]   fs/*verilator sc_bv*/,
   input wire [9:0]   ks/*verilator sc_bv*/,
   input wire [4:0]   kh/*verilator sc_bv*/,
   input wire [4:0]   kw/*verilator sc_bv*/
   );

   parameter f_num  = 16;

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
/*
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
      .s_fin(),
      .k_init(),
      .k_fin(),
      .exec(),
      .ia(),
      .outr(),
      .oa(),
      .kn(),
      .wa(),
      .ra(),
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
*/
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
                .wa(prm_a[9:0]),
                .ra(wa[9:0]),
                .d(d),
                .wd(src_data[31:16]),
                .signo(signo[i]),
                .expo(expo[i]),
                .addo(addo[i])
                );
      end
   endgenerate

endmodule
