# tyny-dnn アクセラレータ作成中

## 概要

AXI Stream で 1サンプル分のデータを受け取り、core で畳み込み計算をして、AXI Stream で 1サンプル分の結果を吐き出します。  
source buffer と destination buffer に 1サンプル分の入出力データを置くためのバッファを持ちます。  
sample controller で 1サンプル内の制御をして、batch controller でミニバッチ 1層の制御をします。  
今はまだ、順方向伝搬だけしか対応していません。  

![](top.png)

## もう少し細かく

### sample controller
batch controller からリクエストを受けて
1. カーネルごとに入力データのアドレスを生成してデータを取ってきつつ計算する
2. 1カーネル分の計算が終わると出力データのアドレスを生成してデータを吐き出す
3. 終わったらストライド分(1限定だけど)だけ移動して、1サンプルの計算が終わるまで繰り返す

1サンプルの計算が終わると batch controller に知らせます。

### batch controller
CPU からリクエストを受けて
1. 入力側の AXI Stream の ready を上げて 1サンプル分のデータを受け取る
2. 入力側の AXI Stream の ready を下げて、sample controller にリクエストを投げる
3. sample controller から計算終了の通知を受けると 出力側の AXI Stream の valid を上げる
4. 1サンプル分のデータを出力したら valid をさげて、ミニバッチ分だけ繰り返す

ミニバッチが終わると CPU に制御を戻します。

### core
畳み込みの計算をしますが、この説明は別の機会に…

## 検証環境
Verilator とコラボした協調検証環境(全部手彫り)です。  
すごく遅いですが、次のコマンドを打つと動きます。

[sim_lv1 ブランチ](https://github.com/tom01h/tiny-dnn/tree/sim_lv1) は FPU が偽物で、比較的高速なシミュレーションができます。  
master ブランチは FPU が本物なので、シミュレーションが遅いです。

```
$ make
$ sim/Vtiny_dnn_top --data_path ../../data/ --learning_rate 1 --epochs 1 --minibatch_size 16 --backend_type internal
```

## FPGA で動かすには

Verilog ファイルは ```CORA/tiny_dnn_top.v, tiny_dnn_reg.v``` と ```examples/mnist/tiny_dnn_buf.sv, tiny_dnn_control.sv, tiny_dnn_core.sv``` を使います。

実行するプログラムは ```CORA/conv2d_op_internal.h, train.cpp``` で ```tiny_dnn/core/kernels/, examples/mnist/``` を上書きします。  

## 使っている NN モデル
こんな感じ。  
PC で学習させると12秒くらいで終わります。  
学習データも20000に削っています。
```
nn << conv(28, 28, 5, 1, 6, padding::valid, true, 1, 1, backend_type)
   << max_pool(24, 24, 6, 2)
   << relu()
   << conv(12, 12, 5, 6, 16, padding::valid, true, 1, 1, backend_type)
   << max_pool(8, 8, 16, 2)
   << relu()
   << conv(4, 4, 4, 16, 10, padding::valid, true, 1, 1, backend_type)
   << softmax(10);
```
