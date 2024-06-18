# tnCart

TangNano20K を搭載した MSX 用カートリッジ

## カートリッジ基板
基板は WonderTang のピンアサインとほぼ同じで、バッファ IC は2電源タイプに変更してます。
また、信号の衝突を防ぐために INT 信号はオープンコレクタに変更してあります。

## たぶん動く機能
- 4MB 拡張 RAM
- NEXTOR と TF カード制御
- FM 音源カートリッジ(BIOS はまだ)
- PSG 音源の 3.5mmフォンジャック出力
- メガロムエミュレーション
- SCC 音源

## 今後の予定
- PAC エミュレーション

## 使用モジュール
各機能の実装に下記モジュールを使用しています。
- PSG https://github.com/dnotq/ym2149_audio
- OPLL https://github.com/hra1129/one-chip-msx-kai/tree/main/source/pld/src/sound/opll/vm2413
