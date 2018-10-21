# tiny-dnn を FPGA で実行する

オリジナルの [tiny-dnn のリポジトリ](https://github.com/tiny-dnn/tiny-dnn)

課題は ```examples/mnist``` を軽量化して実験中です。

## アクセラレータ実装に向けて準備中
まずは Verilator とコラボして、協調検証環境(全部手彫り)を構築中です。
シーケンサを作りかけですが、```examples/mnist``` 以下で次のコマンドを打つと動きます。

```
$ make
$ sim/Vtiny_dnn_top --data_path ../../data/ --learning_rate 1 --epochs 1 --minibatch_size 16 --backend_type internal
```

今回は課題が MNIST でネットが小さいので、最大 16並列で作っています。
