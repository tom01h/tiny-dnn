module tiny_dnn_top
  (
   input wire         clk,
   input wire         write,
   input wire         init,
   input wire         exec,
   input wire [12:0]  a,
   input wire [31:0]  d,
   output wire [31:0] x
   );

   parameter f_num  = 16;

   wire [31:0]       sum [0:15];
   wire [15:0]       bf_d;

   always_ff @(posedge clk)begin
      if(~write&~init&~exec)
        x <= sum[a];
   end

   assign bf_d[15]   = d[31];
   assign bf_d[14:7] = d[30:23];
   assign bf_d[6:0]  = d[22:16];

   generate
      genvar i;
      for (i = 0; i < f_num; i = i + 1) begin
         tiny_dnn_core tiny_dnn_core
               (
                .clk(clk),
                .write(write&(a[12:9] == i)),
                .init(init),
                .exec(exec),
                .a(a[8:0]),
                .d(bf_d),
                .sum(sum[i])
                );
      end
   endgenerate

endmodule

module tiny_dnn_core
  (
   input wire        clk,
   input wire        write,
   input wire        init,
   input wire        exec,
   input wire [8:0]  a,
   input wire [15:0] d, // bFloat16
   output reg [31:0] sum // Signle
   );

   parameter f_size = 512;

   reg [15:0]         W [0:f_size-1];
   wire [31:0]        sumo;

   always_ff @(posedge clk)begin
      if(write)begin
         W[a] <= d;
      end
      if(init)begin
         sum <= 0;
      end
      if(exec)begin
         sum <= sumo;
      end
   end

   fma fma
     (
      .sum(sum[31:0]),
      .w(W[a][15:0]),
      .d(d[15:0]),
      .out(sumo[31:0])
   );

endmodule

module fma
  (
   input wire [31:0] sum,
   input wire [15:0] w,
   input wire [15:0] d,
   output reg [31:0] out
   );

   integer           frac;
   integer           expo;
   integer           expd;
   integer           add;

   always_comb begin
      frac = {9'h1,w[6:0]}  * {9'h1,d[6:0]};
      expo = {1'b0,w[14:7]} + {1'b0,d[14:7]} -127;
      expd = {1'b0,sum[30:23]} - expo;
   end

   always_comb begin
      if(sum[31]^w[15]^d[15])begin
         if(sum[30:23]==8'h0)
           add = -frac;
         else if(expd>=0)
           add = ({1'h1,sum[22:9]}<<expd   ) - frac;
         else
           add = ({1'h1,sum[22:9]}>>(-expd)) - frac;
      end else begin
         if(sum[30:23]==8'h0)
           add = frac;
         else if(expd>=0)
           add = ({1'h1,sum[22:9]}<<expd   ) + frac;
         else
           add = ({1'h1,sum[22:9]}>>(-expd)) + frac;
      end
   end

   wire [31:0] nrm5, nrm4, nrm3, nrm2, nrm1, nrm0;
   integer     exp4, exp3, exp2, exp1, exp0, expn;
   wire        sign;

   always_comb begin
      if(add<0)begin
         nrm5[31:0]=-add;
         sign=~sum[31];
      end else begin
         nrm5[31:0]=add;
         sign=sum[31];
      end

      if(nrm5[31:16]!=0)begin
         nrm4=nrm5[31:0];
         exp4=0;
      end else begin
         nrm4={nrm5[15:0],16'h0000};
         exp4=-16;
      end

      if(nrm4[31:24]!=0)begin
         nrm3=nrm4[31:0];
         exp3=0;
      end else begin
         nrm3={nrm4[23:0],8'h00};
         exp3=-8;
      end

      if(nrm3[31:28]!=0)begin
         nrm2=nrm3[31:0];
         exp2=0;
      end else begin
         nrm2={nrm3[27:0],4'h0};
         exp2=-4;
      end

      if(nrm2[31:30]!=0)begin
         nrm1=nrm2[31:0];
         exp1=0;
      end else begin
         nrm1={nrm2[29:0],2'b00};
         exp1=-2;
      end

      if(nrm1[31])begin
         nrm0=nrm1[31:0];
         exp0=0;
      end else begin
         nrm0={nrm1[30:0],1'b0};
         exp0=-1;
      end

      expn = expo+17+exp4+exp3+exp2+exp1+exp0;
   end

   always_comb begin
      if(expo<=0)begin             // mul = 0
         out = sum;
      end else if(expd>16)begin    // mul << sum
         out = sum;
      end else if(expn<=0)begin    // result = 0
         out = 0;
      end else begin
         out[31]    = sign;
         out[30:23] = expn;
         out[22:9]  = nrm0[30:17];
         out[8:0]   = 0;
      end
   end

endmodule
