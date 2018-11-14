/*
    Copyright (c) 2013, Taiga Nomi and the respective contributors
    All rights reserved.

    Use of this source code is governed by a BSD-style license that can be found
    in the LICENSE file.
*/
#include "Vtiny_dnn_top.h"
extern Vtiny_dnn_top* verilator_top;
extern void eval();

#pragma once

#include <chrono>    // for high_resolution_clock, NOLINT
std::chrono::high_resolution_clock::time_point cst;
std::chrono::high_resolution_clock::duration cft, cbt;

int cf=0;
int cb=0;

union{
  int i;
  float f;
} conv;

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
  //if(0){
    verilator_top->ss = iw*ih*id-1;
    verilator_top->id = id-1;
    verilator_top->is = iw*ih;
    verilator_top->ih = ih-1;
    verilator_top->iw = iw-1;
    verilator_top->ds = ow*oh*od-1;
    verilator_top->od = od-1;
    verilator_top->os = ow*oh;
    verilator_top->oh = oh-1;
    verilator_top->ow = ow-1;
    verilator_top->fs = kw*kh*id-1;
    verilator_top->kh = kh-1;
    verilator_top->kw = kw-1;


    verilator_top->backprop = 0;
    verilator_top->enbias = 1;
    verilator_top->wwrite = 0;
    verilator_top->bwrite = 0;
    verilator_top->run = 0;
    verilator_top->src_valid = 0;
    verilator_top->dst_ready = 1;
    eval();

    verilator_top->wwrite = 1;
    eval();
    verilator_top->src_valid = 1;
    for(size_t i=0;i<od*id*kh*kw;i++){
      conv.f = W[i];
      verilator_top->src_data = conv.i;
      eval();
    }
    verilator_top->src_valid = 0;
    eval();
    verilator_top->wwrite = 0;
    eval();

    verilator_top->bwrite = 1;
    eval();
    verilator_top->src_valid = 1;
    for (size_t o = 0; o < od; o++) {
      if (params.has_bias) {
        conv.f = bias[o];
        verilator_top->src_data = conv.i;
      }else{
        verilator_top->src_data = 0;
      }
      eval();
    }
    verilator_top->src_valid = 0;
    eval();
    verilator_top->bwrite = 0;
    eval();

    verilator_top->run = 1;
    eval();
    verilator_top->src_valid = 1;

    for (size_t sample = 0; sample < in_data.size(); sample++) {
      size_t ina=0;
      size_t outa=0;
      const vec_t &in = in_data[sample];
      vec_t &a        = out_data[sample];

      while(!verilator_top->dst_valid) {
        if(verilator_top->src_ready){
          conv.f = in[ina++];
          verilator_top->src_data = conv.i;
        }
        eval();
      }
      
      while(verilator_top->dst_valid){
        conv.i = verilator_top->dst_data;
        a[outa++] = conv.f;
        eval();
        if((outa%1024==0)&verilator_top->dst_valid){
          verilator_top->dst_ready = 0;
          eval();
          verilator_top->dst_ready = 1;
        }
      }
    }

    verilator_top->enbias = 0;
    verilator_top->src_valid = 0;
    verilator_top->run = 0;
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

  verilator_top->ss = ow*oh*od-1;
  verilator_top->id = od-1;
  verilator_top->is = ow*oh;
  verilator_top->ih = oh-1;
  verilator_top->iw = ow-1;
  verilator_top->ds = iw*ih*id-1;
  verilator_top->od = id-1;
  verilator_top->os = iw*ih;
  verilator_top->oh = ih-1;
  verilator_top->ow = iw-1;
  verilator_top->fs = kw*kh*od-1;
  verilator_top->ks = kw*kh-1;
  verilator_top->kh = kh-1;
  verilator_top->kw = kw-1;


  verilator_top->backprop = 1;
  verilator_top->enbias = 0;
  verilator_top->wwrite = 0;
  verilator_top->bwrite = 0;
  verilator_top->run = 0;
  verilator_top->src_valid = 0;
  verilator_top->dst_ready = 1;
  eval();

  verilator_top->wwrite = 1;
  eval();
  verilator_top->src_valid = 1;
  for(size_t i=0;i<od*id*kh*kw;i++){
    conv.f = W[i];
    verilator_top->src_data = conv.i;
    eval();
  }
  verilator_top->src_valid = 0;
  eval();
  verilator_top->wwrite = 0;
  eval();

  verilator_top->run = 1;
  eval();
  verilator_top->src_valid = 1;

  // NOT supported parametor
  // params.tbl.is_connected
  // params.w_stride
  // params.h_stride
  for (size_t sample = 0; sample < prev_out.size(); sample++) {

    size_t ina=0;
    size_t outa=0;
    const vec_t &in = curr_delta[sample];
    vec_t &a        = prev_delta[sample];

    while(!verilator_top->dst_valid) {
      if(verilator_top->src_ready){
        conv.f = in[ina++];
        verilator_top->src_data = conv.i;
      }
      eval();
    }

    while(verilator_top->dst_valid){
      conv.i = verilator_top->dst_data;
      a[outa++] = conv.f;
      eval();
    }

    // propagate delta to previous layer
    if(0){
      for (size_t inc = 0; inc < id; inc++) {
        for (size_t y = 0; y < ih; y++) {
          for (size_t x = 0; x < iw; x++) {
            int yy = (y-kh+1);
            int xx = (x-kw+1);

            float_t sum{0};
            for (size_t outc = 0; outc < od; outc++) {
              for (int wy = 0; wy < kh; wy++) {   // NOLINT
                if((yy+wy)<0){wy=-yy;}
                if((yy+wy)==oh){break;}
                for (int wx = 0; wx < kw; wx++) {  // NOLINT
                  if((xx+wx)<0){wx=-xx;}
                  if((xx+wx)==ow){break;}
                  sum +=
                    W[id*outc*kh*kw + inc*kh*kw + (kh-1-wy)*kw + (kw-1-wx)] *
                    curr_delta[sample][outc*oh*ow + (yy+wy)*ow + (xx+wx)];
                }
              }
            }
            prev_delta[sample][inc*ih*iw + y*iw + x] = sum;
          }
        }
      }
    }
  }
  verilator_top->backprop = 0;
  verilator_top->src_valid = 0;
  verilator_top->run = 0;

  for (size_t sample = 0; sample < prev_out.size(); sample++) {
    // accumulate dw
    for (size_t inc = 0; inc < params.in.depth_; inc++) {
      for (size_t outc = 0; outc < params.out.depth_; outc++) {
        if (!params.tbl.is_connected(outc, inc)) continue;

        for (size_t wy = 0; wy < params.weight.height_; wy++) {
          for (size_t wx = 0; wx < params.weight.width_; wx++) {
            float_t dst{0};

            size_t idx           = 0;
            idx                  = params.in_padded.get_index(wx, wy, inc);
            const float_t *prevo = &prev_out[sample][idx];

            idx                  = params.out.get_index(0, 0, outc);
            const float_t *delta = &curr_delta[sample][idx];

            if (params.w_stride > 1) {
              for (size_t y = 0; y < params.out.height_; y++) {
                size_t prevo_idx =
                  y * params.in_padded.width_ * params.h_stride;
                size_t delta_idx = y * params.out.width_;

                for (size_t x = 0; x < params.out.width_; x++) {
                  dst += prevo[prevo_idx + x * params.w_stride] *
                         delta[delta_idx + x];
                }
              }
            } else {
              for (size_t y = 0; y < params.out.height_; y++) {
                dst += vectorize::dot(
                  prevo + y * params.in_padded.width_ * params.h_stride,
                  delta + y * params.out.width_, params.out.width_);
              }
            }

            idx = params.in.depth_ * outc + inc;
            dW[sample][params.weight.get_index(wx, wy, idx)] += dst;
          }
        }
      }
    }

    // accumulate db
    if (params.has_bias) {
      for (size_t outc = 0; outc < params.out.depth_; outc++) {
        size_t idx            = params.out.get_index(0, 0, outc);
        const float_t *delta  = &curr_delta[sample][idx];
        const float_t *deltaa = delta + params.out.width_ * params.out.height_;
        db[sample][outc] += std::accumulate(delta, deltaa, float_t{0});
      }
    }
  };
  cbt += std::chrono::high_resolution_clock::now() - cst;
  if(++cb==3750) std::cout << "cov back "
                           << std::chrono::duration_cast<std::chrono::milliseconds>(cbt).count() << "ms elapsed"
                           << std::endl;
}

}  // namespace kernels
}  // namespace tiny_dnn
