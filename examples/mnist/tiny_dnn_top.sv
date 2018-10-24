module tiny_dnn_top
  (
   input wire         clk,

   input wire         src_valid,
   input real         src_data,
   input wire         src_last,
   output wire        src_ready,

   output wire        dst_valid,
   output real        dst_data,
   output wire        dst_last,
   input wire         dst_ready,

   input wire         s_init,

   input wire         init,
   input wire         write,
   input real         d,

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
   input wire [2:0]   kh,
   input wire [2:0]   kw
   );

   parameter f_num  = 16;

   //  batch control <-> sample control
   wire               s_init_; //TEMP//TEMP//
   wire               s_fin;

   // sample control -> core
   wire               k_init;
   wire               k_fin;
   wire [12:0]        wa;
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
   real               dd; //TEMP//TEMP//
   real               sum [0:15];
   real               x;
   always_comb begin
      x = sum[ra];
   end


   batch_ctrl batch_ctrl
     (
      .clk(clk),
      .s_init(s_init_),
      .s_fin(s_fin),
      .src_valid(src_valid),
      .src_last(src_last),
      .src_ready(src_ready),
      .src_v(src_v),
      .src_a(src_a[11:0]),
      .dst_valid(dst_valid),
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
      .src_d(src_data),
      .exec(exec|k_init),
      .ia(ia[11:0]),
      .d(dd)
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
      .init(init),
      .write(write),
      .s_init(s_init|s_init_),//TEMP//TEMP//
      .s_fin(s_fin),
      .k_init(k_init),
      .k_fin(k_fin),
      .exec(exec),
      .ia(ia[11:0]),
      .outr(outr),
      .oa(oa[11:0]),
      .wa(wa[12:0]),
      .ra(ra[3:0]),
      .id(id[3:0]),
      .is(is[9:0]),
      .ih(ih[4:0]),
      .iw(iw[4:0]),
      .od(od[3:0]),
      .os(os[9:0]),
      .oh(oh[4:0]),
      .ow(ow[4:0]),
      .kh(kh[2:0]),
      .kw(kw[2:0])
   );

   generate
      genvar i;
      for (i = 0; i < f_num; i = i + 1) begin
         tiny_dnn_core tiny_dnn_core
               (
                .clk(clk),
                .init(k_init),
                .write(write&(wa[12:9] == i)),
                .exec(exec),
                .bias(k_fin),
                .a(wa[8:0]),
                .d(d),
                .dd(dd), //TEMP//TEMP//
                .sum(sum[i])
                );
      end
   endgenerate

endmodule

module batch_ctrl
  (
   input wire        clk,
   output wire       s_init,
   input wire        s_fin,
   input wire        src_valid,
   input wire        src_last,
   output wire       src_ready,
   output wire       src_v,
   output reg [11:0] src_a,
   output reg        dst_valid,
   output reg        dst_v,
   output reg [11:0] dst_a,

   input wire [11:0] ss,
   input wire [11:0] ds
   );
   assign src_v = src_valid;
   assign src_ready = 1'b1;
 
   always_ff @(posedge clk)begin
      if(~src_valid)begin//TEMP//TEMP//
         src_a <= 0;
      end else if(src_valid) begin
         src_a <= src_a + 1;
      end
      s_init <= (src_a==ss);
   end

   always_ff @(posedge clk)begin
      if(s_fin)begin
         dst_valid <= 1'b1;
         dst_v <= 1'b1;
         dst_a <= 0;
      end else if(dst_a!=ds)begin
         dst_a <= dst_a + 1;
      end else begin
         dst_v <= 1'b0;
      end
      dst_valid <= dst_v;
   end
endmodule

module src_buf
  (
   input wire        clk,
   input wire        src_v,
   input wire [11:0] src_a,
   input real        src_d,
   input wire        exec,
   input wire [11:0] ia,
   output real       d
   );

   real              buff [0:4095];

   always_ff @(posedge clk)begin
      if(src_v)begin
         buff[src_a] <= src_d;
      end
      if(exec)begin
         d <= buff[ia];
      end
   end
endmodule

module dst_buf
  (
   input wire        clk,
   input wire        dst_v,
   input wire [11:0] dst_a,
   output real       dst_d,
   input wire        outr,
   input wire [11:0] oa,
   input real        x
   );

   real              buff [0:4095];

   always_ff @(posedge clk)begin
      if(outr)begin
         buff[oa] <= x;
      end
      if(dst_v)begin
         dst_d <= buff[dst_a];
      end
   end
endmodule

module sample_ctrl
  (
   input wire        clk,
   input wire        s_init,
   output reg        k_init,
   output reg        s_fin,
   input wire        init,
   input wire        write,
   output reg        exec,
   output reg        outr,
   output reg [12:0] wa,
   output reg [12:0] ia,
   output reg [3:0]  ra,
   output reg [12:0] oa,
   output reg        k_fin,
   input wire [3:0]  id,
   input wire [9:0]  is,
   input wire [4:0]  ih,
   input wire [4:0]  iw,
   input wire [3:0]  od,
   input wire [9:0]  os,
   input wire [4:0]  oh,
   input wire [4:0]  ow,
   input wire [2:0]  kh,
   input wire [2:0]  kw
   );

   parameter f_size = 512;

   reg [3:0]  inc;
   reg [2:0]  wy;
   reg [2:0]  wx;


   reg [4:0]  kx;
   reg [9:0]  ka;

   reg [12:0] iac;

   reg [3:0] outc;
   reg [9:0] outp;
   reg       outrp;

   always_ff @(posedge clk)begin
      if(s_init)begin
         wa <= (wa+f_size)&~(f_size-1);
         //k_init <= 1'b1;
         k_init <= ~write;
      end else if(k_init|init)begin
         k_init <= 1'b0;
         exec <= k_init;
         inc <= 0;
         wy <= 0;
         wx <= 0;
         wa <= 0;
         ia <= ka;
         iac <= ka;
         k_fin <= 1'b0;
      end else if(exec|write)begin
         wa <= wa+1;
         if(wx != kw)begin
            wx <= wx +1;
            ia <= ia+1;
         end else if(wy != kh)begin
            wx <= 0;
            wy <= wy +1;
            ia <= ia+iw-kw+1;
         end else if(inc != id)begin
            wx <= 0;
            wy <= 0;
            inc <= inc +1;
            iac <= iac+is;
            ia  <= iac+is;
         end else begin
            wx <= 0;
            wy <= 0;
            inc <= 0;
            exec <= 1'b0;
            k_fin <= exec;
         end
      end else begin
         k_fin <= 1'b0;
         s_fin <= 1'b0;
         if(outrp&(outc==od))begin
            if(outp+1==os)
              s_fin <= 1'b1;
            else
              k_init <= 1'b1;
         end
      end
   end

   always_ff @(posedge clk)begin
      if(s_init)begin
         kx <= 0;
         ka <= 0;
      end else if(k_fin)begin
         if(kx != ow)begin
            kx <= kx+1;
            ka <= ka+1;
         end else begin
            kx <= 0;
            ka <= ka+iw-ow+1;
         end
      end
   end

   always_ff @(posedge clk)begin
      outr <= outrp;
      if(~outr)begin
         ra <= 0;
      end else begin
         ra <= ra+1;
      end
      if(~(outrp&outr))begin
         oa <= outp;
      end else begin
         oa <= oa+os;
      end
      if(s_init)begin
         outp <= 0;
      end else if(~outrp&outr)begin
         outp <= outp+1;
      end
      if(k_fin)begin
         outc <= 0;
         outrp <= 1'b1;
      end else if(outc!=od)begin
         outc <= outc+1;
      end else begin
         outrp <= 1'b0;
      end
   end

endmodule

module tiny_dnn_core
  (
   input wire       clk,
   input wire       init,
   input wire       write,
   input wire       exec,
   input wire       bias,
   input wire [8:0] a,
   input real       d,
   input real       dd, //TEMP//TEMP//
   output real      sum
   );

   parameter f_size = 512;

   real          W [0:f_size-1];
   real          w;
   reg           exec1,bias1;

   always_ff @(posedge clk)begin
      if(write)begin
         W[a] <= d;
      end
      if(init)begin
         sum <= 0;
      end
      exec1 <= exec;
      bias1 <= bias;
      if(exec|bias)begin
         w <= W[a];
      end
      if(exec1)begin
         sum <= sum + w * dd;
      end
      if(bias1)begin
         sum <= sum + w;
      end
   end

endmodule
