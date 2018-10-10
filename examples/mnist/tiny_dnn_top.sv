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

   wire               signo [0:15];
   wire signed [9:0]  expo [0:15];
   wire signed [31:0] addo [0:15];

   reg [31:0]         nrm5, nrm4, nrm3, nrm2, nrm1, nrm0;
   reg signed [9:0]   expd, expn;
   reg                sign;

   always_comb begin
      if(addo[a]<0)begin
         nrm5[31:0]=-addo[a];
         sign=~signo[a];
      end else begin
         nrm5[31:0]=addo[a];
         sign=signo[a];
      end

      expd[9:5] = 0;

      if(nrm5[31:16]!=0)begin
         nrm4=nrm5[31:0];
         expd[4]=0;
      end else begin
         nrm4={nrm5[15:0],16'h0000};
         expd[4]=1;
      end

      if(nrm4[31:24]!=0)begin
         nrm3=nrm4[31:0];
         expd[3]=0;
      end else begin
         nrm3={nrm4[23:0],8'h00};
         expd[3]=1;
      end

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

      expn = expo[a]-expd+17-127;
   end

   always_ff @(posedge clk)begin
      if(~write&~init&~exec)
        if(expn<=0)begin
           x <= 0;
        end else begin
           x[31]    <= sign;
           x[30:23] <= expn;
           x[22:0]  <= nrm0[30:8];
        end
   end

   wire [15:0]        bf_d;

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
                .signo(signo[i]),
                .expo(expo[i]),
                .addo(addo[i])
                );
      end
   endgenerate

endmodule

module tiny_dnn_core
  (
   input wire                clk,
   input wire                write,
   input wire                init,
   input wire                exec,
   input wire [8:0]          a,
   input wire [15:0]         d, // bfloat16
   output wire               signo,
   output wire signed [9:0]  expo,
   output wire signed [31:0] addo
   );

   parameter f_size = 512;

   reg [15:0]         W [0:f_size-1];

   reg [15:0]         Wl;
   reg [15:0]         dl;
   reg                en;

   always_ff @(posedge clk)begin
      en <= exec;
      if(exec)begin
         dl <= d;
      end
   end

   always_ff @(posedge clk)
     if(exec)
       Wl <= W[a];

   always_ff @(posedge clk)
     if(write)
       W[a] <= d;

   fma fma
     (
      .clk(clk),
      .init(init),
      .exec(en),
      .w(Wl[15:0]),
      .d(dl[15:0]),
      .signo(signo),
      .expo(expo[9:0]),
      .addo(addo[31:0])
   );

endmodule

module fma
  (
   input wire               clk,
   input wire               init,
   input wire               exec,
   input wire [15:0]        w,
   input wire [15:0]        d,
   output reg               signo,
   output reg signed [9:0]  expo,
   output reg signed [31:0] addo
   );

   reg signed [16:0] frac;
   reg signed [9:0]  expm;
   reg signed [9:0]  expd;
   reg signed [32:0] add0;
   reg signed [48:0] alin;
   reg               sftout;

   always_comb begin
      frac = {9'h1,w[6:0]}  * {9'h1,d[6:0]};
      expm = {1'b0,w[14:7]} + {1'b0,d[14:7]};
      expd = expm - expo + 16;

      if(signo^w[15]^d[15])
        add0 = -addo;
      else
        add0 = addo;

      if(expd[9:6]!=0)
        alin = 0;
      else
        alin = $signed({add0,16'h0})>>>expd[5:0];

      sftout = (expd<0) | (alin[48:30]!={19{1'b0}}) & (alin[48:30]!={19{1'b1}});
   end

   always_ff @(posedge clk)begin
      if(init)begin
         signo <= 0;
         expo <= 0;
         addo <= 0;
      end else if(exec)begin
         if(~sftout)begin
            signo <= w[15]^d[15];
            expo <= expm;
            addo <= frac + alin;
         end
      end
   end

endmodule
