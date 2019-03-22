module batch_ctrl
  (
   input wire        clk,
   output reg        s_init,
   input wire        s_fin,
   input wire        run,
   input wire        src_valid,
   input wire        src_last,
   output reg        src_ready,
   output wire       src_v,
   output reg [11:0] src_a,
   output reg        dst_valid,
   input wire        dst_ready,
   output wire       dst_v,
   output reg [11:0] dst_a,

   input wire [11:0] ss,
   input wire [11:0] ds
   );

   reg               dst_vi;
   assign dst_v = dst_vi & dst_ready;

   assign src_v = run & src_valid & src_ready;
 
   always_ff @(posedge clk)begin
      if(~run)begin
         src_a <= 0;
         s_init <= 1'b0;
         src_ready <= 1'b1;
      end else begin
         if(~src_ready)begin
            src_a <= 0;
         end else if(src_valid & src_ready) begin
            src_a <= src_a + 1;
         end
         if(src_a==ss)begin
            s_init <= 1'b1;
            src_ready <= 1'b0;
         end else begin
            s_init <= 1'b0;
         end
         if(dst_valid & ~dst_vi)begin
            src_ready <= 1'b1;
         end
      end
   end

   always_ff @(posedge clk)begin
      if(~run)begin
         dst_vi <= 1'b0;
         dst_a <= 0;
      end else if(s_fin)begin
         dst_vi <= 1'b1;
         dst_a <= 0;
      end else if(dst_a!=ds)begin
         if(dst_vi&dst_ready)
           dst_a <= dst_a + 1;
      end else if(dst_ready)begin
         dst_vi <= 1'b0;
      end
      if(dst_ready)begin
         dst_valid <= dst_vi;
      end
   end
endmodule
/*
module sample_ctrl
  (
   input wire        clk,
   input wire        src_valid,
   input wire        src_ready,
   input wire        backprop,
   input wire        run,
   input wire        wwrite,
   input wire        bwrite,
   input wire        s_init,
   output reg        s_fin,
   output reg        k_init,
   output reg        k_fin,
   output reg        exec,
   output reg [12:0] ia,
   output reg        outr,
   output reg [12:0] oa,
   output reg [3:0]  kn,
   output reg [9:0]  wa,
   output reg [3:0]  ra,
   input wire [3:0]  id,
   input wire [9:0]  is,
   input wire [4:0]  ih,
   input wire [4:0]  iw,
   input wire [3:0]  od,
   input wire [9:0]  os,
   input wire [4:0]  oh,
   input wire [4:0]  ow,
   input wire [9:0]  fs,
   input wire [9:0]  ks,
   input wire [4:0]  kh,
   input wire [4:0]  kw
   );

   reg [3:0]  inc;
   reg [4:0]  wy;
   reg [4:0]  wx;


   reg signed [5:0] kx, ky;
   reg [9:0]  ka;

   reg [12:0] iac;

   reg [3:0]  outc;
   reg [9:0]  outp;
   reg        outrp;

   wire       init = ~(wwrite|bwrite|run);
   wire       bwrite_v = bwrite & src_valid & src_ready;
   wire       wwrite_v = wwrite & src_valid & src_ready & ~backprop;

   wire       bwwrite_v = wwrite & src_valid & src_ready & backprop;

   wire [2:0] nwx = backprop&(kx<0) ? -kx : 0 ;
   wire [2:0] nwy = backprop&(ky<0) ? -ky : 0 ;

   always_ff @(posedge clk)begin
      if(init)begin
         k_init <= 1'b0;
         exec <= 1'b0;
         inc <= 0;
         kn <= 0;
         if(backprop)begin
            wx <= kw;
            wy <= kh;
            wa <= ks;
         end else begin
            wy <= 0;
            wx <= 0;
            wa <= 0;
         end
         ia <= 0;
         iac <= 0;
         k_fin <= 1'b0;
         s_fin <= 1'b0;
      end else if(s_init)begin
         k_init <= 1'b1;
      end else if(k_init)begin
         k_init <= 1'b0;
         exec <= 1'b1;
         inc <= 0;
         wy <= nwy;
         wx <= nwx;
         wa <= nwy * (kw+1) + nwx;/////////////////////
         ia <= ka;
         iac <= ka;
         k_fin <= 1'b0;
      end else if(bwrite_v | wwrite_v&(wa==fs))begin
         kn <= kn + 1;
         wa <= 0;
      end else if(exec|wwrite_v)begin
         wa <= wa+1;
         if((wx != kw) & (~backprop|((kx+wx) != iw)))begin
            wx <= wx +1;
            ia <= ia+1;
         end else if((wy != kh) & (~backprop|((ky+wy) != ih)))begin
            wx <= nwx;
            wy <= wy +1;
            ia <= ia+iw-kw+nwx+1;
            if(backprop)begin
               wa <= (wy+1) * (kw+1) + nwx + inc * (ks+1);/////////////////////
               if(kx+kw>iw)begin
                  ia <= ia+nwx+1+kx;
               end
            end
         end else if(inc != id)begin
            wy <= nwy;
            wx <= nwx;
            if(backprop)begin
               wa <= nwy * (kw+1) + nwx + (inc+1) * (ks+1);/////////////////////
            end
            inc <= inc +1;
            iac <= iac+is;
            ia  <= iac+is;
         end else begin
            wy <= nwy;
            wx <= nwx;
            if(backprop)begin
               wa <= nwy * (kw+1) + nwx;
            end
            inc <= 0;
            exec <= 1'b0;
            k_fin <= exec;
         end
      end else if(bwwrite_v)begin
         wa <= wa-1;
         if(wx != 0)begin
            wx <= wx -1;
         end else if(wy != 0)begin
            wx <= kw;
            wy <= wy -1;
         end else if(kn != od)begin
            wx <= kw;
            wy <= kh;
            kn <= kn + 1;
            wa <= wa+ks;
         end else if(inc != id)begin
            wx <= kw;
            wy <= kh;
            inc <= inc +1;
            kn <= 0;
            wa <= wa + ks*2 + 1;
         end else begin
            wx <= kw;
            wy <= kh;
            inc <= 0;
         end
      end else begin
         k_fin <= 1'b0;
         s_fin <= 1'b0;
         if(outrp&(outc==od))begin
            if(outp+1!=os)
              k_init <= 1'b1;
         end
         if(outr&(ra==od))begin
            if(outp+1==os)
              s_fin <= 1'b1;
         end
      end
   end


   always_ff @(posedge clk)begin
      if(s_init|init)begin
         if(~backprop)begin
            kx <= 0;
            ky <= 0;
         end else begin
            kx <= -kw;
            ky <= -kh;
         end
         ka <= 0;
      end else if(k_fin)begin
         if(~backprop)begin
            if(kx != ow)begin
               kx <= kx+1;
               ka <= ka+1;
            end else if(ky != oh)begin
               kx <= 0;
               ka <= ka+iw-ow+1;
               ky <= ky+1;
            end else begin
               kx <= 0;
               ka <= ka-((iw+1)*oh+ow)+is;////////////////////////////////
               ky <= 0;
            end
         end else begin
            if(kx != iw)begin
               kx <= kx+1;
               if(kx>=0)begin
                  ka <= ka+1;
               end
            end else begin
               kx <= -kw;
               if(ky>=0)begin
                  ka <= ka+1;
               end else begin
                  ka <= 0;
               end
               ky <= ky+1;
            end
         end
      end
   end

   always_ff @(posedge clk)begin
      outr <= outrp;
      if(~outr|init)begin
         ra <= 0;
      end else begin
         ra <= ra+1;
      end
      if(~(outrp&outr)|init)begin
         oa <= outp;
      end else begin
         oa <= oa+os;
      end
      if(s_init|init)begin
         outp <= 0;
      end else if(~outrp&outr)begin
         outp <= outp+1;
      end
      if(k_fin|init)begin
         outc <= 0;
         outrp <= k_fin;
      end else if(outc!=od)begin
         outc <= outc+1;
      end else begin
         outrp <= 1'b0;
      end
   end

endmodule
*/
