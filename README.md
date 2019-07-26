# 新しいリポジトリに引っ越しました

[ここです](https://github.com/tom01h/tiny-dnn-fpga)

Depthwise separable convolution に手を付けています

# tiny-dnn を FPGA で実行する

tiny-dnn の畳み込みレイヤを Zynq の PL 部に作ったアクセラレータ回路にオフロードすることで、CNN の学習を加速します。  
課題は ```examples/mnist``` を使用、サンプルの Le-Net を今時の単純な CNN に変更・軽量化して実験中です。

オリジナルの [tiny-dnn のリポジトリ](https://github.com/tiny-dnn/tiny-dnn)

## CPU だけで実行する

[このコミット](https://github.com/tom01h/tiny-dnn/tree/fa7d77bf524b4604d6088ae5a944193f1c2464af)を使う

### WSL 上で実行するには
ホストPCの ```examples/mnist``` 以下で

```
$ g++ -pthread -Wall -Wpedantic -Wno-narrowing -Wno-deprecated -O3 -DNDEBUG -std=gnu++14 -I ../../ -DDNN_USE_IMAGE_API train.cpp -o train
$ ./train --data_path ../../data/ --learning_rate 1 --epochs 1 --minibatch_size 16 --backend_type internal
```

### Zynq 上で実行するには
ホストPCの ```examples/mnist``` 以下でクロスコンパイルして
```
$ ${SDK path}/gnu/aarch32/nt/gcc-arm-linux-gnueabi/bin/arm-linux-gnueabihf-g++.exe -O3 -mfpu=neon -mtune=cortex-a9 -mcpu=cortex-a9 -mfloat-abi=hard -Wall -Wpedantic -Wno-narrowing -Wno-deprecated -DNDEBUG -std=gnu++14 -I ../../ -DDNN_USE_IMAGE_API train.cpp -o train
```

SD カードに ```train, data/``` をコピーして Zynq の Linux 上で
```
root@Cora-Z7-07S:~# mount /dev/mmcblk0p1 /mnt/
root@Cora-Z7-07S:~# /mnt/train --data_path /mnt/data/ --learning_rate 1 --epochs 1 --minibatch_size 16 --backend_type internal
```
#### ZynqMP の場合は
コンパイルコマンドを以下に変更
```
$ ${SDK path}/gnu/aarch64/nt/aarch64-linux/bin/aarch64-linux-gnu-g++.exe -O3 -mtune=cortex-a53 -mcpu=cortex-a53 -Wall -Wpedantic -Wno-narrowing -Wno-deprecated -DNDEBUG -std=gnu++14 -I ../../ -DDNN_USE_IMAGE_API train.cpp -o train
```

## アクセラレータ実装中

畳み込みの行列乗算を 16MAC で並列に計算して学習を加速します。  
説明は ```examples/mnist/readme.md``` に整備中です。

このくらい高速になります。  
ただし、次の変更をソフトウェアに入れています。

1. 入力データの傾きを求める計算をスキップする
2. 畳み込みレイヤで ΔW をミニバッチ分だけ累積する (FPGA(wPL)のみ)

![](speed.svg)

### 残件

- (済) ΔW を累積する
- ディレイ対策 → 周波数アップ
- pooling のアクセラレータ化？
- 演算並列度あげる

