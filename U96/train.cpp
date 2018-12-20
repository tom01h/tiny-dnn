/*
    Copyright (c) 2013, Taiga Nomi and the respective contributors
    All rights reserved.

    Use of this source code is governed by a BSD-style license that can be found
    in the LICENSE file.
*/

#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

volatile int *dnn_addr;
volatile int *dma_addr;
float *src0_addr;
float *src1_addr;
float *dst0_addr;
float *dst1_addr;
unsigned long src0_phys;
unsigned long src1_phys;
unsigned long dst0_phys;
unsigned long dst1_phys;

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

  //train_labels.resize(3008);
  //train_images.resize(3008);
  train_labels.resize(20000);
  train_images.resize(20000);
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

int main(int argc, char **argv) {
  double learning_rate                   = 1;
  int epochs                             = 1;
  std::string data_path                  = "";
  int minibatch_size                     = 16;
  tiny_dnn::core::backend_t backend_type = tiny_dnn::core::default_engine();

  int fd0,fd1,fd2,fd3,dma,dnn;

  if ((fd0  = open("/sys/class/udmabuf/udmabuf0/phys_addr", O_RDONLY)) != -1) {
    char attr[1024];
    read(fd0, attr, 1024);
    sscanf(attr, "%lx", &src0_phys);
    close(fd0);
  }
  if ((fd0  = open("/sys/class/udmabuf/udmabuf1/phys_addr", O_RDONLY)) != -1) {
    char attr[1024];
    read(fd0, attr, 1024);
    sscanf(attr, "%lx", &src1_phys);
    close(fd0);
  }
  if ((fd0  = open("/sys/class/udmabuf/udmabuf2/phys_addr", O_RDONLY)) != -1) {
    char attr[1024];
    read(fd0, attr, 1024);
    sscanf(attr, "%lx", &dst0_phys);
    close(fd0);
  }
  if ((fd0  = open("/sys/class/udmabuf/udmabuf3/phys_addr", O_RDONLY)) != -1) {
    char attr[1024];
    read(fd0, attr, 1024);
    sscanf(attr, "%lx", &dst1_phys);
    close(fd0);
  }

  /* メモリアクセス用のデバイスファイルを開く */
  if ((fd0 = open("/dev/udmabuf0", O_RDWR)) < 0) {
    perror("open");
    return -1;
  }
  if ((fd1 = open("/dev/udmabuf1", O_RDWR)) < 0) {
    perror("open");
    return -1;
  }
  if ((fd2 = open("/dev/udmabuf2", O_RDWR)) < 0) {
    perror("open");
    return -1;
  }
  if ((fd3 = open("/dev/udmabuf3", O_RDWR)) < 0) {
    perror("open");
    return -1;
  }
  if ((dma = open("/dev/uio1", O_RDWR | O_SYNC)) < 0) {
    perror("open");
    return -1;
  }
  if ((dnn = open("/dev/uio2", O_RDWR | O_SYNC)) < 0) {
    perror("open");
    return -1;
  }

  /* ARM(CPU)から見た物理アドレス → 仮想アドレスへのマッピング */
  dnn_addr = (int*)mmap(NULL, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, dnn, 0);
  if (dnn_addr == MAP_FAILED) {
    perror("mmap");
    close(dnn);
    return -1;
  }
  dma_addr = (int*)mmap(NULL, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, dma, 0);
  if (dma_addr == MAP_FAILED) {
    perror("mmap");
    close(dma);
    return -1;
  }
  src0_addr = (float*)mmap(NULL, 0x00040000, PROT_READ | PROT_WRITE, MAP_SHARED, fd0, 0);
  if (src0_addr == MAP_FAILED) {
    perror("mmap");
    close(fd0);
    return -1;
  }
  src1_addr = (float*)mmap(NULL, 0x00040000, PROT_READ | PROT_WRITE, MAP_SHARED, fd1, 0);
  if (src1_addr == MAP_FAILED) {
    perror("mmap");
    close(fd1);
    return -1;
  }
  dst0_addr = (float*)mmap(NULL, 0x00040000, PROT_READ | PROT_WRITE, MAP_SHARED, fd2, 0);
  if (dst0_addr == MAP_FAILED) {
    perror("mmap");
    close(fd2);
    return -1;
  }
  dst1_addr = (float*)mmap(NULL, 0x00040000, PROT_READ | PROT_WRITE, MAP_SHARED, fd3, 0);
  if (dst1_addr == MAP_FAILED) {
    perror("mmap");
    close(fd3);
    return -1;
  }

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
