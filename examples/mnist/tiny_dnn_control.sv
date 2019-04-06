module batch_ctrl
  (
   input wire        clk,
   output reg        s_init,
   input wire        s_fin,
   input wire        backprop,
   input wire        run,
   input wire        wwrite,
   input wire        bwrite,

   input wire        src_valid,
   input wire        src_last,
   output reg        src_ready,
   output reg        dst_valid,
   input wire        dst_ready,

   output reg [3:0]  prm_v,
   output reg [9:0]  prm_a,
   output wire       src_v,
   output reg [11:0] src_a,
   output wire       dst_v,
   output reg [11:0] dst_a,

   input wire [11:0] ss,
   input wire [11:0] ds,
   input wire [3:0]  id,
   input wire [3:0]  od,
   input wire [9:0]  fs,
   input wire [9:0]  ks
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

   reg [3:0]  inc;
   reg [5:0]  wi;


   wire       init = ~(wwrite|bwrite);
   wire       bwrite_v = bwrite & src_valid & src_ready;
   wire       wwrite_v = wwrite & src_valid & src_ready & ~backprop;

   wire       bwwrite_v = wwrite & src_valid & src_ready & backprop;

   always_ff @(posedge clk)begin
      if(init)begin
         inc <= 0;
         prm_v <= 0;
         if(backprop)begin
            wi <= ks;
            prm_a <= ks;
         end else begin
            wi <= 0;
            prm_a <= 0;
         end
      end else if(bwrite_v | wwrite_v&(prm_a==fs))begin
         prm_v <= prm_v + 1;
         prm_a <= 0;
      end else if(wwrite_v)begin
         prm_a <= prm_a+1;
         if(wi != ks)begin
            wi <= wi +1;
         end else if(inc != id)begin
            wi <= 0;
            inc <= inc +1;
         end else begin
            wi <= 0;
            inc <= 0;
         end
      end else if(bwwrite_v)begin
         prm_a <= prm_a-1;
         if(wi != 0)begin
            wi <= wi -1;
         end else if(prm_v != od)begin
            wi <= ks;
            prm_v <= prm_v + 1;
            prm_a <= prm_a+ks;
         end else if(inc != id)begin
            wi <= ks;
            inc <= inc +1;
            prm_v <= 0;
            prm_a <= prm_a + ks*2 + 1;
         end else begin
            wi <= ks;
            inc <= 0;
         end
      end
   end
endmodule

module out_ctrl
  (
   input wire        clk,
   input wire        run,
   input wire        s_init,
   output wire       out_busy,
   input wire        k_fin,
   input wire [3:0]  od,
   input wire [9:0]  os,
   output reg        outr,
   output reg [3:0]  ra,
   output reg [11:0] oa
   );

   reg [3:0]        cnt;
   reg [9:0]        wi;

   reg              out0;

   assign out_busy = (cnt!=od);

   always_ff @(posedge clk)begin
      if(~run)begin
         out0 <= 0;
         cnt <= od;
      end else if(k_fin)begin
         out0 <= 1;
         cnt <= 0;
      end else if(cnt!=od)begin
         out0 <= 1;
         cnt <= cnt+1;
      end else begin
         out0 <= 0;
      end

      outr <= out0;

      if(~run)begin
         ra <= 0;
      end else if(out0)begin
         ra <= cnt;
         if(outr)begin
            oa <= oa+os;
         end else begin
            oa <= wi;
         end
      end

      if(~run|s_init)begin
         wi <= 0;
      end else if(~out0&outr)begin
         wi <= wi+1;
      end
   end

endmodule
