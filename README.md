# tiny-dnn を FPGA で実行する

オリジナルの [tiny-dnn のリポジトリ](https://github.com/tiny-dnn/tiny-dnn)

課題は ```examples/mnist``` を軽量化して実験中です。

## ソフトだけの実装の使い方

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
$ arm-linux-gnueabi-g++ -O3 -mfpu=neon -mtune=cortex-a9 -mcpu=cortex-a9 -mfloat-abi=softfp -Wall -Wpedantic -Wno-narrowing -Wno-deprecated -DNDEBUG -std=gnu++14 -I ../../ -DDNN_USE_IMAGE_API train.cpp -o train -static
```

SD カードに ```train, data/``` をコピーして Zynq の Linux 上で
```
root@Cora-Z7-07S:~# mount /dev/mmcblk0p1 /mnt/
root@Cora-Z7-07S:~# /mnt/train --data_path /mnt/data/ --learning_rate 1 --epochs 1 --minibatch_size 16 --backend_type internal
```

#### Petalinux を作るには
Vivado でビットストリーム込みの hdf ファイルをエクスポート、```peta/project_1.sdk```にコピーして、
```
$ cd peta
$ petalinux-create --type project --template zynq --name tiny-dnn
$ cd tiny-dnn/
$ petalinux-config --get-hw-description=../project_1.sdk
$ petalinux-build
$ petalinux-package --boot --force --fsbl images/linux/zynq_fsbl.elf --fpga images/linux/system.bit --u-boot
```

上記で作成した ```images/linux/BOOT.bin, image.ub``` を SD カードにコピーして Zynq をブートする。

## アクセラレータ実装に向けて準備中
まずは Verilator とコラボして、協調検証環境(全部手彫り)を構築中です。
すごく遅いですが、```examples/mnist``` 以下で次のコマンドを打つと動きます。

```
$ make
$ sim/Vtiny_dnn_top --data_path ../../data/ --learning_rate 1 --epochs 1 --minibatch_size 16 --backend_type internal
```

アクセラレータの使い方は、内蔵するウェイトメモリのアドレスを指定してデータを書き込むと、指定アドレスからウェイトを読み出して、書き込みデータと掛け算をして、結果を内部レジスタに累積していきます。  
今回は課題が MNIST でネットが小さいので、最大 16並列で作っています。  
パラメータと畳み込み層に入力するデータは bFloat16 で計算しています。累積途中の仮数は 16bit 精度で計算して、出力は単精度(下位は0うめ)です。
変換は0方向丸め(言い換えると下位ビット無視)です。  
まだステージを切っていないので、周波数が全くでないと思われる構成です。
