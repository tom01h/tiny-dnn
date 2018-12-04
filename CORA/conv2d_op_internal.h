/*
    Copyright (c) 2013, Taiga Nomi and the respective contributors
    All rights reserved.

    Use of this source code is governed by a BSD-style license that can be found
    in the LICENSE file.
*/

#define SRC_BASE   (0x1ff00000)
#define DST_BASE   (0x1ff80000)

extern volatile int *dnn_addr;
extern volatile int *dma_addr;
extern float *src_addr;
extern float *dst_addr;

#pragma once

#include <chrono>    // for high_resolution_clock, NOLINT
std::chrono::high_resolution_clock::time_point cst;
std::chrono::high_resolution_clock::duration cft, cbt;

int cf=0;
int cb=0;

namespace tiny_dnn {
namespace kernels {

inline void conv2d_op_internal(const tensor_t &in_data,
                               const vec_t &W,
                               const vec_t &bias,
                               tensor_t &out_data,
                               const core::conv_params &params,
                               const bool parallelize) {
  cst = std::chrono::high_resolution_clock::now();


  size_t out_area    = params.out.area();
  size_t iw          = params.in_padded.width_;
  size_t ih          = params.in_padded.height_;
  size_t id          = params.in.depth_;
  size_t ow          = params.out.width_;
  size_t oh          = params.out.height_;
  size_t od          = params.out.depth_;
  size_t kw          = params.weight.width_;
  size_t kh          = params.weight.height_;
  size_t elem_stride = params.w_stride;
  size_t line_stride = iw * params.h_stride;

  // NOT supported parametor
  // params.tbl.is_connected
  // params.w_stride
  // params.h_stride
  if(in_data.size()>1){

    dnn_addr[ 5] = iw*ih*id-1; //ss
    dnn_addr[ 6] = id-1;       //id
    dnn_addr[ 7] = iw*ih;      //is
    dnn_addr[ 8] = ih-1;       //ih
    dnn_addr[ 9] = iw-1;       //iw

    dnn_addr[10] = ow*oh*od-1; //ds
    dnn_addr[11] = od-1;       //od
    dnn_addr[12] = ow*oh;      //os
    dnn_addr[13] = oh-1;       //oh
    dnn_addr[14] = ow-1;       //ow

    dnn_addr[ 1] = kw*kh*id-1; //fs
    dnn_addr[ 2] = kw*kh-1;    //ks
    dnn_addr[ 3] = kh-1;       //kh
    dnn_addr[ 4] = kw-1;       //kw


    /////////////////////////////////////////////////////////
    // Weight transfer
    // AXI DMA reset
    dma_addr[0x00/4] = 4;
    while (dma_addr[0x00/4] & 0x4); // Wait for reset finish

    // DMA Buffer
    for(size_t i=0;i<od*id*kh*kw;i++){
      src_addr[i] = W[i];
    }

    dnn_addr[0] = 0; // init
    dnn_addr[0] = 2; // wwrite

    // AXI DMA transfer tx
    dma_addr[0x00/4] = 1;
    dma_addr[0x18/4] = SRC_BASE;
    dma_addr[0x28/4] = od*id*kh*kw*4;

    while ((dma_addr[0x04/4] & 0x3)==0); // Wait for the tx to finish

    /////////////////////////////////////////////////////////
    // Bias transfer
    // AXI DMA reset
    dma_addr[0x00/4] = 4;
    while (dma_addr[0x00/4] & 0x4); // Wait for reset finish

    // DMA Buffer
    for (size_t o = 0; o < od; o++) {
      if (params.has_bias) {
        src_addr[o] = bias[o];
      }else{
        src_addr[o] = 0;
      }
    }

    dnn_addr[0] = 0; // init
    dnn_addr[0] = 1; // bwrite

    // AXI DMA transfer tx
    dma_addr[0x00/4] = 1;
    dma_addr[0x18/4] = SRC_BASE;
    dma_addr[0x28/4] = od*4;

    while ((dma_addr[0x04/4] & 0x3)==0); // Wait for the tx to finish

    /////////////////////////////////////////////////////////
    // Run
    dnn_addr[0] = 0;   // init
    dnn_addr[0] = 4|8; // run|enbias

    for (size_t sample = 0; sample < in_data.size(); sample++) {
      const vec_t &in = in_data[sample];
      vec_t &a        = out_data[sample];

      // AXI DMA reset
      dma_addr[0x30/4] = 4;
      dma_addr[0x00/4] = 4;
      while (dma_addr[0x00/4] & 0x4); // Wait for reset finish

      /////////////////////////////////////////////////////////
      // in data
      for(size_t i=0;i<iw*ih*id;i++){
        src_addr[i] = in[i];
      }

      // AXI DMA transfer rx
      dma_addr[0x30/4] = 1;
      dma_addr[0x48/4] = DST_BASE;
      dma_addr[0x58/4] = ow*oh*od*4;

      // AXI DMA transfer tx
      dma_addr[0x00/4] = 1;
      dma_addr[0x18/4] = SRC_BASE;
      dma_addr[0x28/4] = iw*ih*id*4;

      // Wait for the tx to finish
      while ((dma_addr[0x04/4] & 0x3)==0);

      // Wait for the rx to finish
      while ((dma_addr[0x34/4] & 0x3)==0) ;

      for(size_t i=0;i<od*oh*ow;i++){
        a[i] = dst_addr[i];
      }
    }

    dnn_addr[0] = 0; // idle

  }else{
    for (size_t sample = 0; sample < in_data.size(); sample++) {
      const vec_t &in = in_data[sample];
      vec_t &a        = out_data[sample];
      for (size_t o = 0; o < od; o++) {
        float_t *pa = &a[params.out.get_index(0, 0, o)];
        for (size_t inc = 0; inc < id; inc++) {
          if (!params.tbl.is_connected(o, inc)) continue;
          size_t idx;
          idx                = params.weight.get_index(0, 0, id * o + inc);
          const float_t *pw  = &W[idx];
          idx                = params.in_padded.get_index(0, 0, inc);
          const float_t *pin = &in[idx];
          float_t *pout      = pa;
          for (size_t y = 0; y < oh; y++) {
            const float_t *pin_line = pin;
            for (size_t x = 0; x < ow; x++) {
              const float_t *pin_element = pin_line;
              const float_t *pw_element  = pw;
              float_t sum{0};
              // should be optimized for small kernel(3x3,5x5)
              for (size_t wy = 0; wy < kh; wy++) {    // NOLINT
                for (size_t wx = 0; wx < kw; wx++) {  // NOLINT
                  sum += pw_element[wx] * pin_element[wx];
                }
                pw_element += kw;
                pin_element += iw;
              }
              pout[x] += sum;
              pin_line += elem_stride;
            }
            pout += ow;
            pin += line_stride;
          }
        }
        if (params.has_bias) {
          vectorize::add(bias[o], out_area, pa);
        }
      }
    }
  }

  cft += std::chrono::high_resolution_clock::now() - cst;
  if(in_data.size()>1){
    if(++cf==3750) std::cout << "cov forward "
                             << std::chrono::duration_cast<std::chrono::milliseconds>(cft).count() << "ms elapsed"
                             << std::endl;
  }
}

/******************************************************************/

template <typename tensor_t, typename vec_t>
void conv2d_op_internal(const tensor_t &prev_out,
                        const vec_t &W,
                        tensor_t &dW,
                        tensor_t &db,
                        tensor_t &curr_delta,
                        tensor_t &prev_delta,
                        const core::conv_params &params,
                        const bool parallelize) {
  typedef typename vec_t::value_type float_t;

  cst = std::chrono::high_resolution_clock::now();

  size_t iw          = params.in_padded.width_;
  size_t ih          = params.in_padded.height_;
  size_t id          = params.in.depth_;
  size_t ow          = params.out.width_;
  size_t oh          = params.out.height_;
  size_t od          = params.out.depth_;
  size_t kw          = params.weight.width_;
  size_t kh          = params.weight.height_;

  dnn_addr[ 5] = ow*oh*od-1; //ss
  dnn_addr[ 6] = od-1;       //id
  dnn_addr[ 7] = ow*oh;      //is
  dnn_addr[ 8] = oh-1;       //ih
  dnn_addr[ 9] = ow-1;       //iw

  dnn_addr[10] = iw*ih*id-1; //ds
  dnn_addr[11] = id-1;       //od
  dnn_addr[12] = iw*ih;      //os
  dnn_addr[13] = ih-1;       //oh
  dnn_addr[14] = iw-1;       //ow

  dnn_addr[ 1] = kw*kh*od-1; //fs
  dnn_addr[ 2] = kw*kh-1;    //ks
  dnn_addr[ 3] = kh-1;       //kh
  dnn_addr[ 4] = kw-1;       //kw

  /////////////////////////////////////////////////////////
  // Weight transfer
  // AXI DMA reset
  dma_addr[0x00/4] = 4;
  while (dma_addr[0x00/4] & 0x4); // Wait for reset finish

  // DMA Buffer
  for(size_t i=0;i<od*id*kh*kw;i++){
    src_addr[i] = W[i];
  }

  dnn_addr[0] = 0|16; // init|backprop
  dnn_addr[0] = 2|16; // wwrite|backprop

  // AXI DMA transfer tx
  dma_addr[0x00/4] = 1;
  dma_addr[0x18/4] = SRC_BASE;
  dma_addr[0x28/4] = od*id*kh*kw*4;

  while ((dma_addr[0x04/4] & 0x3)==0); // Wait for the tx to finish

  /////////////////////////////////////////////////////////
  // Run
  dnn_addr[0] = 0|16; // init|backprop
  dnn_addr[0] = 4|16; // run|backprop

  for (size_t sample = 0; sample < prev_out.size(); sample++) {
    const vec_t &in = curr_delta[sample];
    vec_t &a        = prev_delta[sample];

    // AXI DMA reset
    dma_addr[0x30/4] = 4;
    dma_addr[0x00/4] = 4;
    while (dma_addr[0x00/4] & 0x4); // Wait for reset finish

    /////////////////////////////////////////////////////////
    // in data
    for(size_t i=0;i<ow*oh*od;i++){
      src_addr[i] = in[i];
    }

    // AXI DMA transfer rx
    dma_addr[0x30/4] = 1;
    dma_addr[0x48/4] = DST_BASE;
    dma_addr[0x58/4] = iw*ih*id*4;

    // AXI DMA transfer tx
    dma_addr[0x00/4] = 1;
    dma_addr[0x18/4] = SRC_BASE;
    dma_addr[0x28/4] = ow*oh*od*4;

    // Wait for the tx to finish
    while ((dma_addr[0x04/4] & 0x3)==0);

    // Wait for the rx to finish
    while ((dma_addr[0x34/4] & 0x3)==0) ;

    for(size_t i=0;i<id*ih*iw;i++){
      a[i] = dst_addr[i];
    }
  }

  dnn_addr[ 0] = 0; // idle


  dnn_addr[ 5] = iw*ih*id-1; //ss
  dnn_addr[ 6] = 0;          //id
  dnn_addr[ 7] = iw*ih;      //is
  dnn_addr[ 8] = ih-1;       //ih
  dnn_addr[ 9] = iw-1;       //iw

  dnn_addr[10] = kw*kh*id*od-1;//ds
  dnn_addr[11] = od-1;       //od
  dnn_addr[12] = kw*kh*id;   //os
  dnn_addr[13] = kh-1;       //oh
  dnn_addr[14] = kw-1;       //ow

  dnn_addr[ 1] = ow*oh-1;    //fs
  dnn_addr[ 2] = ow*oh-1;    //ks
  dnn_addr[ 3] = oh-1;       //kh
  dnn_addr[ 4] = ow-1;       //kw

  for (size_t sample = 0; sample < prev_out.size(); sample++) {
    // accumulate dw
    const vec_t &delta = curr_delta[sample];
    const vec_t &prevo = prev_out[sample];
    /////////////////////////////////////////////////////////
    // current delta transfer
    // AXI DMA reset
    dma_addr[0x00/4] = 4;
    while (dma_addr[0x00/4] & 0x4); // Wait for reset finish

    // DMA Buffer
    for(size_t i=0;i<ow*oh*od;i++){
      src_addr[i] = delta[i];
    }

    dnn_addr[0] = 0; // init
    dnn_addr[0] = 2; // wwrite

    // AXI DMA transfer tx
    dma_addr[0x00/4] = 1;
    dma_addr[0x18/4] = SRC_BASE;
    dma_addr[0x28/4] = ow*oh*od*4;

    while ((dma_addr[0x04/4] & 0x3)==0); // Wait for the tx to finish

    dnn_addr[0] = 0; // init
    dnn_addr[0] = 4; // run

    // AXI DMA reset
    dma_addr[0x30/4] = 4;
    dma_addr[0x00/4] = 4;
    while (dma_addr[0x00/4] & 0x4); // Wait for reset finish

    /////////////////////////////////////////////////////////
    // in data
    for(size_t i=0;i<iw*ih*id;i++){
      src_addr[i] = prevo[i];
    }

    // AXI DMA transfer rx
    dma_addr[0x30/4] = 1;
    dma_addr[0x48/4] = DST_BASE;
    dma_addr[0x58/4] = kw*kh*id*od*4;

    // AXI DMA transfer tx
    dma_addr[0x00/4] = 1;
    dma_addr[0x18/4] = SRC_BASE;
    dma_addr[0x28/4] = iw*ih*id*4;

    // Wait for the tx to finish
    while ((dma_addr[0x04/4] & 0x3)==0);

    // Wait for the rx to finish
    while ((dma_addr[0x34/4] & 0x3)==0) ;

    for(size_t i=0;i<kw*kh*id*od;i++){
      dW[sample][i] = dst_addr[i];
    }

    dnn_addr[0] = 0; // idle

    // accumulate db
    if (params.has_bias) {
      for (size_t outc = 0; outc < params.out.depth_; outc++) {
        size_t idx            = params.out.get_index(0, 0, outc);
        const float_t *delta  = &curr_delta[sample][idx];
        const float_t *deltaa = delta + params.out.width_ * params.out.height_;
        db[sample][outc] += std::accumulate(delta, deltaa, float_t{0});
      }
    }
  }
  cbt += std::chrono::high_resolution_clock::now() - cst;
  if(++cb==3750) std::cout << "cov back "
                           << std::chrono::duration_cast<std::chrono::milliseconds>(cbt).count() << "ms elapsed"
                           << std::endl;
}

}  // namespace kernels
}  // namespace tiny_dnn
