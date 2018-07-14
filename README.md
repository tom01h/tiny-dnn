# tiny-dnn を FPGA で実行する

オリジナルの [tiny-dnn のリポジトリ](https://github.com/tiny-dnn/tiny-dnn)

課題は ```examples/mnist``` を軽量化して実験中です。

WSL 上で実行するには
```
$ g++ -pthread -Wall -Wpedantic -Wno-narrowing -Wno-deprecated -O3 -DNDEBUG -std=gnu++14 -I ../../ -DDNN_USE_IMAGE_API train.cpp -o train
$ ./train --data_path ../../data/ --learning_rate 1 --epochs 1 --minibatch_size 16 --backend_type internal
```

Zynq 上で実行するには、ホストPC上でクロスコンパイルして
```
$ arm-linux-gnueabi-g++ -O3 -mfpu=neon -mtune=cortex-a9 -mcpu=cortex-a9 -mfloat-abi=softfp -Wall -Wpedantic -Wno-narrowing -Wno-deprecated -DNDEBUG -std=gnu++14 -I ../../ -DDNN_USE_IMAGE_API train.cpp -o train -static
```

SD カードに ```train, data/``` をコピーして Zynq の Linux 上で
```
root@Cora-Z7-07S:~# mount /dev/mmcblk0p1 /mnt/
root@Cora-Z7-07S:~# /mnt/train --data_path /mnt/data/ --learning_rate 1 --epochs 3 --minibatch_size 16 --backend_type internal
```
