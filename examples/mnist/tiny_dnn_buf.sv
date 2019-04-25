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
      end else if(exec)begin
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

   reg               outrl;
   reg [11:0]        oal;

   always_ff @(posedge clk)begin
      if(outr)begin
         outrl <= 1'b1;
         oal <= oa;
      end else begin
         outrl <= 1'b0;
      end
   end

   always_ff @(posedge clk)begin
      if(outrl)begin
         buff[oal] <= x;
      end else if(dst_v)begin
         dst_d <= buff[dst_a];
      end
   end
endmodule
