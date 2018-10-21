module tiny_dnn_top
  (
   input wire         clk,
   input wire         s_init,
   input wire         init,
   input wire         write,
   input wire         exec,
   input wire         outr,
   output wire [12:0] ia,
   output wire [12:0] oa,
   input real         d,
   output real        x,

   input wire [3:0]   id,
   input wire [9:0]   is,
   input wire [4:0]   ih,
   input wire [4:0]   iw,
   input wire [3:0]   od,
   input wire [9:0]   os,
   input wire [4:0]   oh,
   input wire [4:0]   ow,
   input wire [2:0]   kh,
   input wire [2:0]   kw
   );

   parameter f_num  = 16;

   real               sum [0:15];

   wire [12:0]        wa;
   wire [12:0]        ia;
   wire [3:0]         ra;
   wire               k_fin;

   always_ff @(posedge clk)begin
      x <= sum[ra];
   end

   address_gen address_gen
     (
      .clk(clk),
      .s_init(s_init),
      .init(init),
      .write(write),
      .exec(exec),
      .outr(outr),
      .wa(wa[12:0]),
      .ia(ia[12:0]),
      .ra(ra[3:0]),
      .oa(oa[12:0]),
      .k_fin(k_fin),
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
                .init(init),
                .write(write&(wa[12:9] == i)),
                .exec(exec),
                .bias(k_fin),
                .a(wa[8:0]),
                .d(d),
                .sum(sum[i])
                );
      end
   endgenerate

endmodule

module address_gen
  (
   input wire        clk,
   input wire        s_init,
   input wire        init,
   input wire        write,
   input wire        exec,
   input wire        outr,
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

   always_ff @(posedge clk)begin
      if(s_init)begin
         wa <= (wa+f_size)&~(f_size-1);
      end else if(init)begin
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
            k_fin <= exec;
         end
      end else begin
         k_fin <= 1'b0;
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

   reg [9:0] outp;
   reg       outrr;

   always_ff @(posedge clk)begin
      outrr <= outr;
      if(~outr)begin
         ra <= 0;
      end else begin
         ra <= ra+1;
      end
      if(~(outr&outrr))begin
         oa <= outp;
      end else begin
         oa <= oa+os;
      end
      if(s_init)begin
         outp <= 0;
      end else if(~outr&outrr)begin
         outp <= outp+1;
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
   output real      sum
   );

   parameter f_size = 512;

   real          W [0:f_size-1];

   always_ff @(posedge clk)begin
      if(write)begin
         W[a] <= d;
      end
      if(init)begin
         sum <= 0;
      end
      if(exec)begin
         sum <= sum + W[a] * d;
      end
      if(bias)begin
         sum <= sum + W[a];
      end
   end

endmodule
