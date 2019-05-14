module batch_ctrl
  (
   input wire         clk,
   output reg         s_init,
   input wire         s_fin,
   input wire         backprop,
   input wire         run,
   input wire         wwrite,
   input wire         bwrite,
   input wire         last,

   input wire         src_valid,
   input wire         src_last,
   output reg         src_ready,
   output reg         dst_valid,
   input wire         dst_ready,

   output wire [3:0]  prm_v,
   output wire [9:0]  prm_a,
   output wire        src_v,
   output reg [11:0]  src_a,
   output wire        dst_v,
   output wire [11:0] dst_a,

   output reg         execp,
   output wire        inp,
   output wire        outp,

   input wire [11:0]  ss,
   input wire [11:0]  ds,
   input wire [3:0]   id,
   input wire [3:0]   od,
   input wire [9:0]   fs,
   input wire [9:0]   ks
   );

   assign inp  = ~execp;
   assign outp = ~execp;
   reg [1:0]          src_en;
   wire               src_fin;
   reg                s_fin_h;

   wire               s_fin_in = (s_fin | s_fin_h) & (src_en[inp] | last);

   always @(posedge clk)begin
      if(~run)begin
         s_init <= 1'b0;
         execp <= 1'b1;
         s_fin_h <= 1'b0;
      end else if(src_fin & src_en[1:0]==2'b00)begin
         s_init <= 1'b1;
         execp <= ~execp;
      end else if(s_fin_in)begin
         s_init <= ~last;
         execp <= ~execp;
         s_fin_h <= 1'b0;
      end else if(s_fin)begin
         s_fin_h <= 1'b1;
      end else begin
         s_init <= 1'b0;
      end

      if(~run)begin
         src_en[1:0] <= 2'b00;
      end else if(src_fin)begin
         src_en[inp] <= 1'b1;
      end else if(s_fin_in & src_en[inp])begin
         src_en[execp] <= 1'b0;
      end
   end

////////////////////// dst_v, dst_a /// dst_valid ///////////////

   wire              last_da;
   wire              next_da;
   reg [11:0]        da;

   wire              den = dst_ready;

   wire              dstart, dstart0;
   wire              dst_v0;
   wire              dst_v0_in = s_fin_in|dst_v0&!last_da;

   dff #(.W(1)) d_dstart0 (.in(s_fin_in), .data(dstart0), .clk(clk), .rst(~run), .en(den));
   dff #(.W(1)) d_dst_v0 (.in(dst_v0_in), .data(dst_v0), .clk(clk), .rst(~run), .en(den));

   assign dstart = den&dstart0;

   loop1 #(.W(12)) l_da(.ini(12'd0), .fin(ds),  .data(da), .start(dstart),  .last(last_da),
                        .clk(clk),   .rst(~run),            .next(next_da),   .en(den) );

   assign dst_a = da;
   assign dst_v = dst_v0 & dst_ready;
   dff #(.W(1)) d_dst_valid (.in(dst_v0), .data(dst_valid), .clk(clk), .rst(~run), .en(den));

////////////////////// src_v, src_a /// s_init, src_ready ///////

   wire              last_sa;
   wire              next_sa;
   reg [11:0]        sa;

   wire              sen = src_valid&src_ready;
   wire              sstart = sen&run&~wwrite;

   assign src_ready = (src_en!=2'b11);

   loop1 #(.W(12)) l_sa(.ini(12'd0), .fin(ss),  .data(sa), .start(sstart),  .last(last_sa),
                        .clk(clk),   .rst(~src_ready|~run), .next(next_sa),   .en(sen) );
   assign src_a = sa;
   assign src_v = run & src_valid & src_ready;
   assign src_fin = last_sa;

////////////////////// prm_v, prm_a /////////////////////////////

   wire              last_ic, last_oc, last_ki;
   wire              next_ic, next_oc, next_ki;
   reg [3:0]         ic     , oc;
   reg [9:0]                           ki;

   wire              wstart, wstart0, wstart1;
   wire              wrst = ~(wwrite|bwrite);
   wire              wen = src_valid;

   dff #(.W(1)) d_wstart0 (.in(wwrite|bwrite), .data(wstart0), .clk(clk), .rst(wrst), .en(1'b1));
   dff #(.W(1)) d_wstart1 (.in(wstart0), .data(wstart1), .clk(clk), .rst(wrst), .en(wen));

   assign wstart = wen&wstart0&!wstart1;

   wire [3:0]        ice = (backprop) ? id : 0;

   loop1 #(.W(4))  l_ic(.ini(4'd0),  .fin(ice), .data(ic), .start(wstart),  .last(last_ic),
                        .clk(clk),   .rst(wrst),            .next(next_ic),   .en(last_oc&wen) );

   loop1 #(.W(4) ) l_oc(.ini(4'd0),  .fin(od),  .data(oc), .start(next_ic),  .last(last_oc),
                        .clk(clk),   .rst(wrst),            .next(next_oc),   .en(last_ki&wen) );

   wire [9:0]        kie = (backprop) ? ks : ((bwrite) ? 0 : fs);

   loop1 #(.W(10)) l_ki(.ini(10'd0), .fin(kie), .data(ki), .start(next_oc), .last(last_ki),
                        .clk(clk),   .rst(wrst),            .next(next_ki),   .en(wen)  );

   assign prm_v = oc;
   assign prm_a = (backprop) ? (ic*(ks+1) + ks - ki) : ki;

endmodule

module out_ctrl
  (
   input wire         clk,
   input wire         rst,
   input wire         s_init,
   output wire        out_busy,
   input wire         k_init,
   input wire         k_fin,
   input wire [3:0]   od,
   input wire [9:0]   os,
   output wire        outr,
   output wire [11:0] oa,
   output wire        update
   );

   wire              last_wi, last_ct;
   wire              next_wi, next_ct;
   reg [9:0]         wi;
   reg [3:0]                  ct;

   wire              k_fin0, k_fin1, start;
   wire              out_busy0, out_busy1;

   assign update = start;

   dff #(.W(1)) d_k_fin0 (.in(k_fin), .data(k_fin0), .clk(clk), .rst(rst), .en(1'b1));
   dff #(.W(1)) d_k_fin1 (.in(k_fin0), .data(k_fin1), .clk(clk), .rst(rst), .en(!out_busy1|k_fin0));
   dff #(.W(1)) d_start (.in(k_fin1&!out_busy1), .data(start), .clk(clk), .rst(rst), .en(1'b1));

   dff #(.W(1)) d_out_busy0 (.in(k_fin|out_busy0&((ct+2)!=od)|out_busy1), .data(out_busy0),
                             .clk(clk), .rst(rst), .en(1'b1));
   dff #(.W(1)) d_out_busy1 (.in((k_fin|out_busy1)&out_busy), .data(out_busy1),
                             .clk(clk), .rst(rst), .en(1'b1));
   dff #(.W(1)) d_out_busy (.in((k_init&out_busy0|out_busy)&((ct+2)!=od)), .data(out_busy),
                            .clk(clk), .rst(rst), .en(1'b1));

   wire              outr_in = k_fin1|outr&!last_ct;
   dff #(.W(1)) d_outr (.in(outr_in), .data(outr), .clk(clk), .rst(rst), .en(1'b1));

   loop1 #(.W(10)) l_wi(.ini(10'd0), .fin(os-1),.data(wi), .start(s_init),  .last(last_wi),
                        .clk(clk),   .rst(rst),             .next(next_wi),   .en(last_ct)  );

   loop1 #(.W(4))  l_ct(.ini(4'd0),  .fin(od),  .data(ct), .start(start),   .last(last_ct),
                        .clk(clk),   .rst(rst),             .next(next_ct),   .en(1'b1)  );

   assign oa = ct*os+wi;

endmodule
