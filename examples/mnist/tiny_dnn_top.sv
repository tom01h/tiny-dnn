module tiny_dnn_top
  (
   input wire         clk,

   input wire         backprop,
   input wire         enbias,
   input wire         run,
   input wire         wwrite,
   input wire         bwrite,

   input wire         src_valid,
   input wire [31:0]  src_data,
   input wire         src_last,
   output wire        src_ready,

   output wire        dst_valid,
   output wire [31:0] dst_data,
   output wire        dst_last,
   input wire         dst_ready,

   input wire [11:0]  ss,
   input wire [3:0]   id,
   input wire [9:0]   is,
   input wire [4:0]   ih,
   input wire [4:0]   iw,
   input wire [11:0]  ds,
   input wire [3:0]   od,
   input wire [9:0]   os,
   input wire [4:0]   oh,
   input wire [4:0]   ow,
   input wire [9:0]   fs,
   input wire [9:0]   ks,
   input wire [4:0]   kh,
   input wire [4:0]   kw
   );

   parameter f_num  = 16;

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
                .a(wa[8:0]),
                .d(d),
                .wd(src_data[31:16]),
                .signo(signo[i]),
                .expo(expo[i]),
                .addo(addo[i])
                );
      end
   endgenerate

endmodule
