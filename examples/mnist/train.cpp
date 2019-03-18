/*
    Copyright (c) 2013, Taiga Nomi and the respective contributors
    All rights reserved.

    Use of this source code is governed by a BSD-style license that can be found
    in the LICENSE file.
*/

// verilator
#include "systemc.h"
#include "tiny_dnn_sc_ctl.h"
#include "unistd.h"
#include "getopt.h"
#include "Vtiny_dnn_top.h"
#include "verilated.h"
#include "verilated_vcd_sc.h"

sc_time vcdstart(0,SC_NS);
sc_time vcdend(300000,SC_NS);

int tfpv=0;
VerilatedVcdSc * tfp;

sc_signal <bool>      backprop;
sc_signal <bool>      enbias;
sc_signal <bool>      run;
sc_signal <bool>      wwrite;
sc_signal <bool>      bwrite;

sc_signal <bool>      src_valid;
sc_signal <uint32_t > src_data;
sc_signal <bool>      src_last;
sc_signal <bool>      src_ready;

sc_signal <bool>      dst_valid;
sc_signal <uint32_t > dst_data;
sc_signal <bool>      dst_last;
sc_signal <bool>      dst_ready;

sc_signal <uint32_t > vss;
sc_signal <uint32_t > vid;
sc_signal <uint32_t > vis;
sc_signal <uint32_t > vih;
sc_signal <uint32_t > viw;
sc_signal <uint32_t > vds;
sc_signal <uint32_t > vod;
sc_signal <uint32_t > vos;
sc_signal <uint32_t > voh;
sc_signal <uint32_t > vow;
sc_signal <uint32_t > vfs;
sc_signal <uint32_t > vks;
sc_signal <uint32_t > vkh;
sc_signal <uint32_t > vkw;
// verilator

void eval()
{
  if((tfpv==0)&(sc_time_stamp()>=vcdstart)){
    tfpv=1;
    tfp->open("tmp.vcd");
  }

  sc_start(10, SC_NS);

  if(tfpv==1){
    if(sc_time_stamp()>vcdend){
      tfp->close();
      tfpv=2;
    }
  }

  return;
}
// verilator

#include <iostream>

#include "tiny_dnn/tiny_dnn.h"

static void construct_net(tiny_dnn::network<tiny_dnn::sequential> &nn,
                          tiny_dnn::core::backend_t backend_type) {

  //using fc       = tiny_dnn::fully_connected_layer;
  using conv     = tiny_dnn::convolutional_layer;
  using max_pool = tiny_dnn::max_pooling_layer;
  using relu     = tiny_dnn::relu_layer;
  using softmax  = tiny_dnn::softmax_layer;
  //using avg_pool = tiny_dnn::average_pooling_layer;

  using tiny_dnn::core::connection_table;
  using padding = tiny_dnn::padding;

  nn << conv(28, 28, 5, 1, 6, padding::valid, true, 1, 1, backend_type)
     << max_pool(24, 24, 6, 2)
     << relu()
     << conv(12, 12, 5, 6, 16, padding::valid, true, 1, 1, backend_type)
     << max_pool(8, 8, 16, 2)
     << relu()
     << conv(4, 4, 4, 16, 10, padding::valid, true, 1, 1, backend_type)
     << softmax(10);
}

static void train_net(const std::string &data_dir_path,
                        double learning_rate,
                        const int n_train_epochs,
                        const int n_minibatch,
                        tiny_dnn::core::backend_t backend_type) {
  // specify loss-function and learning strategy
  tiny_dnn::network<tiny_dnn::sequential> nn;
  tiny_dnn::adagrad optimizer;

  construct_net(nn, backend_type);

  std::cout << "load models..." << std::endl;

  // load MNIST dataset
  std::vector<tiny_dnn::label_t> train_labels, test_labels;
  std::vector<tiny_dnn::vec_t> train_images, test_images;

  tiny_dnn::parse_mnist_labels(data_dir_path + "/train-labels.idx1-ubyte",
                               &train_labels);
  tiny_dnn::parse_mnist_images(data_dir_path + "/train-images.idx3-ubyte",
                               &train_images, -1.0, 1.0, 0, 0);
  tiny_dnn::parse_mnist_labels(data_dir_path + "/t10k-labels.idx1-ubyte",
                               &test_labels);
  tiny_dnn::parse_mnist_images(data_dir_path + "/t10k-images.idx3-ubyte",
                               &test_images, -1.0, 1.0, 0, 0);

  train_labels.resize(3008);
  train_images.resize(3008);
  //train_labels.resize(20000);
  //train_images.resize(20000);
  //train_labels.resize(32);
  //train_images.resize(32);

  std::cout << "start training" << std::endl;

  tiny_dnn::progress_display disp(train_images.size());
  tiny_dnn::timer t;

  optimizer.alpha *=
    std::min(tiny_dnn::float_t(4),
             static_cast<tiny_dnn::float_t>(sqrt(n_minibatch) * learning_rate));

  int epoch = 1;
  // create callback
  auto on_enumerate_epoch = [&]() {
    std::cout << "Epoch " << epoch << "/" << n_train_epochs << " finished. "
              << t.elapsed() << "s elapsed." << std::endl;
    ++epoch;
    //tiny_dnn::result res = nn.test(test_images, test_labels);
    //std::cout << res.num_success << "/" << res.num_total << std::endl;

    disp.restart(train_images.size());
    t.restart();
  };

  auto on_enumerate_minibatch = [&]() { disp += n_minibatch; };

  // training
  nn.train<tiny_dnn::mse>(optimizer, train_images, train_labels, n_minibatch,
                          n_train_epochs, on_enumerate_minibatch,
                          on_enumerate_epoch);

  std::cout << "end training." << std::endl;

  // test and show results
  nn.test(test_images, test_labels).print_detail(std::cout);
  // save network model & trained weights
  nn.save("Net-model");
}

static tiny_dnn::core::backend_t parse_backend_name(const std::string &name) {
  const std::array<const std::string, 5> names = {{
    "internal", "nnpack", "libdnn", "avx", "opencl",
  }};
  for (size_t i = 0; i < names.size(); ++i) {
    if (name.compare(names[i]) == 0) {
      return static_cast<tiny_dnn::core::backend_t>(i);
    }
  }
  return tiny_dnn::core::default_engine();
}

static void usage(const char *argv0) {
  std::cout << "Usage: " << argv0 << " --data_path path_to_dataset_folder"
            << " --learning_rate 1"
            << " --epochs 1"
            << " --minibatch_size 16"
            << " --backend_type internal" << std::endl;
}

int sc_main(int argc, char **argv) {
  double learning_rate                   = 1;
  int epochs                             = 1;
  std::string data_path                  = "";
  int minibatch_size                     = 16;
  tiny_dnn::core::backend_t backend_type = tiny_dnn::core::default_engine();

  if (argc == 2) {
    std::string argname(argv[1]);
    if (argname == "--help" || argname == "-h") {
      usage(argv[0]);
      return 0;
    }
  }
  for (int count = 1; count + 1 < argc; count += 2) {
    std::string argname(argv[count]);
    if (argname == "--learning_rate") {
      learning_rate = atof(argv[count + 1]);
    } else if (argname == "--epochs") {
      epochs = atoi(argv[count + 1]);
    } else if (argname == "--minibatch_size") {
      minibatch_size = atoi(argv[count + 1]);
    } else if (argname == "--backend_type") {
      backend_type = parse_backend_name(argv[count + 1]);
    } else if (argname == "--data_path") {
      data_path = std::string(argv[count + 1]);
    } else {
      std::cerr << "Invalid parameter specified - \"" << argname << "\""
                << std::endl;
      usage(argv[0]);
      return -1;
    }
  }

// verilator
  Vtiny_dnn_top verilator_top("verilator_top");
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);
  tfp = new VerilatedVcdSc;

  verilator_top.trace(tfp, 99); // requires explicit max levels param

  sc_clock clk ("clk", 10, SC_NS);

  sc_signal <bool>         s_init;
  sc_signal <bool>         k_init;
  sc_signal <uint32_t>     ia;
  sc_signal <uint32_t>     wa;

  tiny_dnn_sc_ctl U_tiny_dnn_sc_ctl("U_tiny_dnn_sc_ctl");
  U_tiny_dnn_sc_ctl.clk(clk);
  U_tiny_dnn_sc_ctl.s_init(s_init);
  U_tiny_dnn_sc_ctl.k_init(k_init);
  U_tiny_dnn_sc_ctl.ia(ia);
  U_tiny_dnn_sc_ctl.wa(wa);

  verilator_top.s_init(s_init);
  verilator_top.sc_k_init(k_init);
  verilator_top.sc_ia(ia);
  verilator_top.sc_wa(wa);

  verilator_top.clk(clk);
  verilator_top.backprop(backprop);
  verilator_top.enbias(enbias);
  verilator_top.run(run);
  verilator_top.wwrite(wwrite);
  verilator_top.bwrite(bwrite);

  verilator_top.src_valid(src_valid);
  verilator_top.src_data(src_data);
  verilator_top.src_last(src_last);
  verilator_top.src_ready(src_ready);

  verilator_top.dst_valid(dst_valid);
  verilator_top.dst_data(dst_data);
  verilator_top.dst_last(dst_last);
  verilator_top.dst_ready(dst_ready);

  verilator_top.ss(vss);
  verilator_top.id(vid);
  verilator_top.is(vis);
  verilator_top.ih(vih);
  verilator_top.iw(viw);
  verilator_top.ds(vds);
  verilator_top.od(vod);
  verilator_top.os(vos);
  verilator_top.oh(voh);
  verilator_top.ow(vow);
  verilator_top.fs(vfs);
  verilator_top.ks(vks);
  verilator_top.kh(vkh);
  verilator_top.kw(vkw);

  sc_start(SC_ZERO_TIME);
  sc_start(5, SC_NS);
// verilator

  if (data_path == "") {
    std::cerr << "Data path not specified." << std::endl;
    usage(argv[0]);
    return -1;
  }
  if (learning_rate <= 0) {
    std::cerr
      << "Invalid learning rate. The learning rate must be greater than 0."
      << std::endl;
    return -1;
  }
  if (epochs <= 0) {
    std::cerr << "Invalid number of epochs. The number of epochs must be "
                 "greater than 0."
              << std::endl;
    return -1;
  }
  if (minibatch_size <= 0 || minibatch_size > 20000) {
    std::cerr
      << "Invalid minibatch size. The minibatch size must be greater than 0"
         " and less than dataset size (20000)."
      << std::endl;
    return -1;
  }
  std::cout << "Running with the following parameters:" << std::endl
            << "Data path: " << data_path << std::endl
            << "Learning rate: " << learning_rate << std::endl
            << "Minibatch size: " << minibatch_size << std::endl
            << "Number of epochs: " << epochs << std::endl
            << "Backend type: " << backend_type << std::endl
            << std::endl;
  try {
    train_net(data_path, learning_rate, epochs, minibatch_size, backend_type);
  } catch (tiny_dnn::nn_error &err) {
    std::cerr << "Exception: " << err.what() << std::endl;
  }
  return 0;
}
