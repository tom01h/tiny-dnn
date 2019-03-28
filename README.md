# tiny-dnn を FPGA で実行する

tiny-dnn の畳み込みレイヤを Zynq の PL 部に作ったアクセラレータ回路にオフロードすることで、CNN の学習を加速します。  
課題は ```examples/mnist``` を使用、サンプルの Le-Net を今時の単純な CNN に変更・軽量化して実験中です。

オリジナルの [tiny-dnn のリポジトリ](https://github.com/tiny-dnn/tiny-dnn)

## アクセラレータ実装中

このブラランチは(master よりは多少)高速な RTL シミュレーション環境専用です。  
実行方法は ```examples/mnist/readme.md``` の検証環境を参照してください。

