module tiny_dnn_top
  (
   input wire        clk,

   input wire        backprop,
   input wire        deltaw,
   input wire        enbias,
   input wire        run,
   input wire        wwrite,
   input wire        bwrite,
   input wire        last,

   output wire       sc_s_init,
   output wire       sc_out_busy,
   input wire        sc_s_fin,
   input wire        sc_k_init,
   input wire        sc_k_fin,
   input wire        sc_exec,
   input wire [11:0] sc_ia,
   input wire [9:0]  sc_wa,

   input wire        src_valid,
   input real        src_data,
   input wire        src_last,
   output wire       src_ready,

   output wire       dst_valid,
   output real       dst_data,
   output wire       dst_last,
   input wire        dst_ready,

   input wire [11:0] ss,
   input wire [3:0]  dd,
   input wire [3:0]  id,
   input wire [9:0]  is,
   input wire [4:0]  ih,
   input wire [4:0]  iw,
   input wire [11:0] ds,
   input wire [3:0]  od,
   input wire [9:0]  os,
   input wire [4:0]  oh,
   input wire [4:0]  ow,
   input wire [9:0]  fs,
   input wire [9:0]  ks,
   input wire [4:0]  kh,
   input wire [4:0]  kw
   );

   parameter f_num  = 16;

   // batch control <-> sample control
   wire               s_init;
   wire               s_fin;
   wire               out_busy;

   // sample control -> core
   wire               k_init;
   wire               k_fin;
   wire [9:0]         wa;

   // sample control -> core, src buffer
   wire               exec;
   wire [11:0]        ia;
   wire               execp;
   wire               inp;
   // out control -> core, dst buffer
   wire               outr;
   wire [11:0]        oa;
   wire               sum_update;
   wire               outp;

   // batch control -> weight buffer
   wire [3:0]         prm_v;
   wire [9:0]         prm_a;
   // batch control -> src buffer
   wire               src_v;
   wire [11:0]        src_a;
   // batch control -> dst buffer
   wire               dst_v;
   wire [11:0]        dst_a;

   // core <-> src,dst buffer
   real               d;
   real               sum [0:f_num];
   real               x;

   always_ff @(posedge clk)begin
      x <= sum[0];
   end

   batch_ctrl batch_ctrl
     (
      .clk(clk),
      .s_init(s_init),
      .s_fin(s_fin),
      .backprop(backprop),
      .run(run),
      .wwrite(wwrite),
      .bwrite(bwrite),
      .last(last),

      .src_valid(src_valid),
      .src_last(src_last),
      .src_ready(src_ready),
      .dst_valid(dst_valid),
      .dst_ready(dst_ready),

      .prm_v(prm_v[3:0]),
      .prm_a(prm_a[9:0]),
      .src_v(src_v),
      .src_a(src_a[11:0]),
      .dst_v(dst_v),
      .dst_a(dst_a[11:0]),

      .execp(execp),
      .inp(inp),
      .outp(outp),

      .ss(ss[11:0]),
      .ds(ds[11:0]),
      .id(id[3:0]),
      .od(od[3:0]),
      .fs(fs[9:0]),
      .ks(ks[9:0])
      );

   src_buf src_buf
     (
      .clk(clk),
      .src_v(src_v),
      .src_a({inp,src_a[11:0]}),
      .src_d(src_data),
      .exec(exec|k_init),
      .ia({execp,ia[11:0]}),
      .d(d)
      );

   dst_buf dst_buf
     (
      .clk(clk),
      .dst_v(dst_v),
      .dst_a({outp,dst_a[11:0]}),
      .dst_d(dst_data),
      .outr(outr),
      .oa({execp,oa[11:0]}),
      .x(x)
      );

   out_ctrl out_ctrl
     (
      .clk(clk),
      .rst(~run),
      .s_init(s_init),
      .k_init(k_init),
      .k_fin(k_fin),
      .out_busy(out_busy),
      .od(od[3:0]),
      .os(os[9:0]),
      .outr(outr),
      .oa(oa[11:0]),
      .update(sum_update)
      );

/*
   assign sc_s_init = s_init;
   assign sc_out_busy = out_busy;
   assign s_fin = sc_s_fin;
   assign k_init = sc_k_init;
   assign k_fin = sc_k_fin;
   assign exec = sc_exec;
   assign ia = sc_ia;
   assign wa = sc_wa;
/**/

   tiny_dnn_ex_ctl tiny_dnn_ex_ctl
     (
      .clk(clk),
      .backprop(backprop),
      .run(run),
      .wwrite(wwrite),
      .bwrite(bwrite),
      .s_init(s_init),
      .out_busy(out_busy),
      .outr(outr),
/**/
      .s_fin(s_fin),
      .k_init(k_init),
      .k_fin(k_fin),
      .exec(exec),
      .ia(ia),
      .wa(wa),
/**/
      .dd(dd),
      .id(id),
      .is(is),
      .ih(ih),
      .iw(iw),
      .od(od),
      .os(os),
      .oh(oh),
      .ow(ow),
      .fs(fs),
      .ks(ks),
      .kh(kh),
      .kw(kw),
      .rst(~run)
      );

   assign sum[f_num] = 0;

   generate
      genvar i;
      for (i = 0; i < f_num; i = i + 1) begin
         tiny_dnn_core tiny_dnn_core
               (
                .clk(clk),
                .init(k_init),
                .write((wwrite|bwrite)&(prm_v[3:0] == i) & src_valid & src_ready),
                .bwrite(bwrite),
                .exec(exec),
                .outr(outr),
                .update(sum_update),
                .bias(k_fin&enbias),
                .ra({deltaw&execp,wa[9:0]}),
                .wa({deltaw&inp,  prm_a[9:0]}),
                .d(d),
                .wd(src_data),
                .sum_in(sum[i+1]),
                .sum(sum[i])
                );
      end
   endgenerate

endmodule
