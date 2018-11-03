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

## アクセラレータ実装中
今はまだ、順方向伝搬だけしか対応していません。  

### WSL 上で実行するには
Verilator とコラボした協調検証環境(全部手彫り)です。  
すごく遅いですが、```examples/mnist``` 以下で次のコマンドを打つと動きます。

[sim_lv1 ブランチ](https://github.com/tom01h/tiny-dnn/tree/sim_lv1) は FPU が偽物で、比較的高速なシミュレーションができます。  
master ブランチは FPU が本物なので、シミュレーションが遅いです。

```
$ make
$ sim/Vtiny_dnn_top --data_path ../../data/ --learning_rate 1 --epochs 1 --minibatch_size 16 --backend_type internal
```


### Zynq 上で実行するには

[このコミット](https://github.com/tom01h/tiny-dnn/tree/4b46b29066069d6fd72caccf22fdf3aeeafc3092)を使う

一応動くようになりましたが、ソフトだけの時よりも遅くなりました。  
高速化に向けて、大幅に構成を変更中です。

コンパイルはソフトだけの時と同じです。

#### Petalinux を作るには
Vivado で Zynq PS と ```CORA/tiny_dnn_top.v, tiny_dnn_core.sv``` をつないでビットストリームを作る。  
その時 ```tiny_dnn_top``` は ```0x40000000``` から ```0x4000ffff``` にマップする。  
Vivado でビットストリーム込みの hdf ファイルをエクスポート、```peta/project_1.sdk```にコピーして、
```
$ source /opt/pkg/petalinux/settings.sh
$ cd peta
$ petalinux-create --type project --template zynq --name tiny-dnn
$ cd tiny-dnn/
$ petalinux-config --get-hw-description=../project_1.sdk
$ vi project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi
$ petalinux-build
$ petalinux-package --boot --force --fsbl images/linux/zynq_fsbl.elf --fpga images/linux/system.bit --u-boot
```

#### 実行は
上記で作成した ```images/linux/BOOT.bin, image.ub``` と、コンパイル済みのソフトと入力データ ```train, data/``` を SD カードにコピーして Zynq をブートする。  
実行コマンドも、ソフトだけの時と同じです。
