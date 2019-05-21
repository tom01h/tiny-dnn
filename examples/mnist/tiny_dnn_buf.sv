module src_buf
  (
   input wire        clk,
   input wire        src_v,
   input wire [12:0] src_a,
   input wire [15:0] src_d0,
   input wire [15:0] src_d1,
   input wire [15:0] src_d2,
   input wire [15:0] src_d3,
   input wire        exec,
   input wire [12:0] ia,
   output reg [15:0] d
   );

   reg [15:0]         buff00 [0:1023];
   reg [15:0]         buff01 [0:1023];
   reg [15:0]         buff02 [0:1023];
   reg [15:0]         buff03 [0:1023];
   reg [15:0]         buff10 [0:1023];
   reg [15:0]         buff11 [0:1023];
   reg [15:0]         buff12 [0:1023];
   reg [15:0]         buff13 [0:1023];

   reg [15:0]         d00, d01, d02, d03;
   reg [15:0]         d10, d11, d12, d13;

   reg [2:0]          ia_l;

   always_ff @(posedge clk)
     if(exec)
       ia_l[2:0] <= {ia[12],ia[1:0]};
   always_comb begin
      case(ia_l[2:0])
        3'd0 : d = d00;
        3'd1 : d = d01;
        3'd2 : d = d02;
        3'd3 : d = d03;
        3'd4 : d = d10;
        3'd5 : d = d11;
        3'd6 : d = d12;
        3'd7 : d = d13;
      endcase
   end

   always_ff @(posedge clk)
     if(    src_v &~src_a[12])               buff00[src_a[9:0]] <= src_d0;
     else if(exec &({ia[12],ia[1:0]}==3'd0)) d00 <= buff00[ia[11:2]];
   always_ff @(posedge clk)
     if(    src_v &~src_a[12])               buff01[src_a[9:0]] <= src_d1;
     else if(exec &({ia[12],ia[1:0]}==3'd1)) d01 <= buff01[ia[11:2]];
   always_ff @(posedge clk)
     if(    src_v &~src_a[12])               buff02[src_a[9:0]] <= src_d2;
     else if(exec &({ia[12],ia[1:0]}==3'd2)) d02 <= buff02[ia[11:2]];
   always_ff @(posedge clk)
     if(    src_v &~src_a[12])               buff03[src_a[9:0]] <= src_d3;
     else if(exec &({ia[12],ia[1:0]}==3'd3)) d03 <= buff03[ia[11:2]];

   always_ff @(posedge clk)
     if(    src_v & src_a[12])               buff10[src_a[9:0]] <= src_d0;
     else if(exec &({ia[12],ia[1:0]}==3'd4)) d10 <= buff10[ia[11:2]];
   always_ff @(posedge clk)
     if(    src_v & src_a[12])               buff11[src_a[9:0]] <= src_d1;
     else if(exec &({ia[12],ia[1:0]}==3'd5)) d11 <= buff11[ia[11:2]];
   always_ff @(posedge clk)
     if(    src_v & src_a[12])               buff12[src_a[9:0]] <= src_d2;
     else if(exec &({ia[12],ia[1:0]}==3'd6)) d12 <= buff12[ia[11:2]];
   always_ff @(posedge clk)
     if(    src_v & src_a[12])               buff13[src_a[9:0]] <= src_d3;
     else if(exec &({ia[12],ia[1:0]}==3'd7)) d13 <= buff13[ia[11:2]];

endmodule

module dst_buf
  (
   input wire         clk,
   input wire         dst_v,
   input wire [12:0]  dst_a,
   output wire [31:0] dst_d0,
   output wire [31:0] dst_d1,
   input wire         outr,
   input wire [12:0]  oa,
   input wire [31:0]  x
   );

   reg [31:0]        buff00 [0:2047];
   reg [31:0]        buff01 [0:2047];
   reg [31:0]        buff10 [0:2047];
   reg [31:0]        buff11 [0:2047];

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

   reg [31:0]        dst_d00, dst_d01, dst_d10, dst_d11;
   assign dst_d0 = (dst_a[12]) ? dst_d01 : dst_d00;
   assign dst_d1 = (dst_a[12]) ? dst_d11 : dst_d10;

   always_ff @(posedge clk)
     if(outrl&~oal[12]&~oal[0])
       buff00[oal[11:1]] <= x;
     else if(dst_v&~dst_a[12])
       dst_d00 <= buff00[dst_a[10:0]];

   always_ff @(posedge clk)
     if(outrl&~oal[12]& oal[0])
       buff01[oal[11:1]] <= x;
     else if(dst_v&~dst_a[12])
       dst_d10 <= buff01[dst_a[10:0]];

   always_ff @(posedge clk)
     if(outrl& oal[12]&~oal[0])
       buff10[oal[11:1]] <= x;
     else if(dst_v& dst_a[12])
       dst_d01 <= buff10[dst_a[10:0]];

   always_ff @(posedge clk)
     if(outrl& oal[12]& oal[0])
       buff11[oal[11:1]] <= x;
     else if(dst_v& dst_a[12])
       dst_d11 <= buff11[dst_a[10:0]];

endmodule
