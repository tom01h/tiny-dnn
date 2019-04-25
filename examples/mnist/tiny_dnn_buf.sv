module src_buf
  (
   input wire        clk,
   input wire        src_v,
   input wire [11:0] src_a,
   input wire [15:0] src_d,
   input wire        exec,
   input wire [11:0] ia,
   output reg [15:0] d
   );

   reg [15:0]        buff [0:4095];

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
   output reg [31:0] dst_d,
   input wire        outr,
   input wire [11:0] oa,
   input wire [31:0] x
   );

   reg [31:0]        buff [0:4095];

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
