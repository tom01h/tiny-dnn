module normalize
  (
   input wire               clk,
   input wire               en,
   input wire               signo,
   input wire signed [9:0]  expo,
   input wire signed [31:0] addo,
   output reg [31:0]        nrm
   );

   reg [31:0]         nrm5, nrm4, nrm3, nrm2, nrm1, nrm0;
   reg signed [9:0]   expn, expl;
   reg [9:0]          expd;
   reg                sign, signl;

   always_comb begin
      if(addo<0)begin
         nrm5[31:0]=-addo;
         sign=~signo;
      end else begin
         nrm5[31:0]=addo;
         sign=signo;
      end

      if(nrm5[31:16]!=0)begin
         nrm4=nrm5[31:0];
         expd[4]=0;
      end else begin
         nrm4={nrm5[15:0],16'h0000};
         expd[4]=1;
      end

      if(nrm4[31:24]!=0)begin
         expd[3]=0;
      end else begin
         expd[3]=1;
      end
   end

   always_ff @(posedge clk)begin
      if(en)begin
         signl <= sign;
         expl <= expo - {1'b0,expd[4:3],3'b000};
         if(nrm4[31:24]!=0)begin
            nrm3<=nrm4[31:0];
         end else begin
            nrm3<={nrm4[23:0],8'h00};
         end
      end
   end

   always_comb begin
      if(nrm3[31:28]!=0)begin
         nrm2=nrm3[31:0];
         expd[2]=0;
      end else begin
         nrm2={nrm3[27:0],4'h0};
         expd[2]=1;
      end

      if(nrm2[31:30]!=0)begin
         nrm1=nrm2[31:0];
         expd[1]=0;
      end else begin
         nrm1={nrm2[29:0],2'b00};
         expd[1]=1;
      end

      if(nrm1[31])begin
         nrm0=nrm1[31:0];
         expd[0]=0;
      end else begin
         nrm0={nrm1[30:0],1'b0};
         expd[0]=1;
      end

      expn = expl-{1'b0,expd[2:0]}+17-127;

      if(expn<=0)begin
         nrm = 0;
      end else begin
         nrm[31]    = signl;
         nrm[30:23] = expn;
         nrm[22:0]  = nrm0[30:8];
      end
   end

endmodule

module tiny_dnn_core
  (
   input wire                clk,
   input wire                init,
   input wire                write,
   input wire                bwrite,
   input wire                exec,
   input wire                sum_ip,
   input wire                sum_op,
   input wire                bias,
   input wire [9:0]          ra,
   input wire [9:0]          wa,
   input wire [15:0]         d, // bfloat16
   input wire [15:0]         wd, // bfloat16
   output wire               signo,
   output wire signed [9:0]  expo,
   output wire signed [31:0] addo
   );

   parameter f_size = 1024;

   reg [15:0]         W [0:f_size-1];

   reg                init1, exec1, bias1, init2, exec2, bias2;
   reg [15:0]         W1, W2;
   reg [15:0]         d2;
   

   always_ff @(posedge clk)begin
      init1 <= init;
      exec1 <= exec;
      bias1 <= bias;
      init2 <= init1;
      exec2 <= exec1;
      bias2 <= bias1;
   end

   wire [9:0]    radr = (bias)   ? f_size-1 : ra ;
   wire [9:0]    wadr = (bwrite) ? f_size-1 : wa ;

   always_ff @(posedge clk)
     if(exec|bias)
       W1 <= W[radr];

   always_ff @(posedge clk)
     if(exec1|bias1)begin
        W2 <= W1;
        d2 <= (exec1) ? d : 16'h3f80;
     end

   always_ff @(posedge clk)
     if(write)
       W[wadr] <= wd;

   fma fma
     (
      .clk(clk),
      .init(init2),
      .exec(exec2|bias2),
      .sum_ip(sum_ip),
      .sum_op(sum_op),
      .w(W2[15:0]),
      .d(d2[15:0]),
      .signo(signo),
      .expo(expo[9:0]),
      .addo(addo[31:0])
   );

endmodule

module fma
  (
   input wire                clk,
   input wire                init,
   input wire                exec,
   input wire                sum_ip,
   input wire                sum_op,
   input wire [15:0]         w,
   input wire [15:0]         d,
   output wire               signo,
   output wire signed [9:0]  expo,
   output wire signed [31:0] addo
   );

   reg signed [16:0]         frac;
   reg signed [9:0]          expm;
   reg signed [9:0]          expd;
   reg signed [32:0]         add0;
   reg signed [48:0]         alin;
   reg                       sftout;

   reg [1:0]                 signi;
   reg signed [1:0] [9:0]    expi;
   reg signed [1:0] [31:0]   addi;

   always_comb begin
      frac = {9'h1,w[6:0]}  * {9'h1,d[6:0]};
      expm = {1'b0,w[14:7]} + {1'b0,d[14:7]};
      expd = expm - expi[sum_ip] + 16;

      if(signi[sum_ip]^w[15]^d[15])
        add0 = -addi[sum_ip];
      else
        add0 = addi[sum_ip];

      if(expd[9:6]!=0)
        alin = 0;
      else
        alin = $signed({add0,16'h0})>>>expd[5:0];

      sftout = (expd<0) | (alin[48:30]!={19{1'b0}}) & (alin[48:30]!={19{1'b1}});
   end

   assign signo = signi[sum_op];
   assign expo = expi[sum_op];
   assign addo = addi[sum_op];

   always_ff @(posedge clk)begin
      if(init)begin
         signi[sum_ip] <= 0;
         expi[sum_ip] <= 0;
         addi[sum_ip] <= 0;
      end else if(exec)begin
         if(~sftout)begin
            signi[sum_ip] <= w[15]^d[15];
            expi[sum_ip] <= expm;
            addi[sum_ip] <= frac + alin;
         end
      end
   end

endmodule
