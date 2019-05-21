module src_buf
  (
   input wire        clk,
   input wire        src_v,
   input wire [12:0] src_a,
   input real        src_d0,
   input real        src_d1,
   input real        src_d2,
   input real        src_d3,
   input wire        exec,
   input wire [12:0] ia,
   output real       d
   );

   real              buff0 [0:4095];
   real              buff1 [0:4095];

   real              d0,d1;
   assign d = (ia[12]) ? d1 : d0;

   always_ff @(posedge clk)begin
      if(src_v&~src_a[12])begin
         buff0[{src_a[9:0],2'd0}] <= src_d0;
         buff0[{src_a[9:0],2'd1}] <= src_d1;
         buff0[{src_a[9:0],2'd2}] <= src_d2;
         buff0[{src_a[9:0],2'd3}] <= src_d3;
      end else if(exec&~ia[12])begin
         d0 <= buff0[ia[11:0]];
      end
   end
   always_ff @(posedge clk)begin
      if(src_v&src_a[12])begin
         buff1[{src_a[9:0],2'd0}] <= src_d0;
         buff1[{src_a[9:0],2'd1}] <= src_d1;
         buff1[{src_a[9:0],2'd2}] <= src_d2;
         buff1[{src_a[9:0],2'd3}] <= src_d3;
      end else if(exec&ia[12])begin
         d1 <= buff1[ia[11:0]];
      end
   end
endmodule

module dst_buf
  (
   input wire        clk,
   input wire        dst_v,
   input wire [12:0] dst_a,
   output real       dst_d0,
   output real       dst_d1,
   input wire        outr,
   input wire [12:0] oa,
   input real        x
   );

   real              buff0 [0:4095];
   real              buff1 [0:4095];

   reg               outrl;
   reg [12:0]        oal;

   always_ff @(posedge clk)begin
      if(outr)begin
         outrl <= 1'b1;
         oal <= oa;
      end else begin
         outrl <= 1'b0;
      end
   end

   real dst_d00, dst_d01, dst_d10, dst_d11;
   assign dst_d0 = (dst_a[12]) ? dst_d01 : dst_d00;
   assign dst_d1 = (dst_a[12]) ? dst_d11 : dst_d10;

   always_ff @(posedge clk)begin
      if(outrl&~oal[12])begin
         buff0[oal[11:0]] <= x;
      end else if(dst_v&~dst_a[12])begin
         dst_d00 <= buff0[{dst_a[10:0],1'd0}];
         dst_d10 <= buff0[{dst_a[10:0],1'd1}];
      end
   end
   always_ff @(posedge clk)begin
      if(outrl&oal[12])begin
         buff1[oal[11:0]] <= x;
      end else if(dst_v&dst_a[12])begin
         dst_d01 <= buff1[{dst_a[10:0],1'd0}];
         dst_d11 <= buff1[{dst_a[10:0],1'd1}];
      end
   end
endmodule
