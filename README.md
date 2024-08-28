# tnCart

TangNano20K を搭載した MSX 用カートリッジ

## カートリッジ基板
回路は WonderTang V1.01c のピンアサインとほぼ同じで、バッファ IC は2電源タイプに変更してます。
また、信号の衝突を防ぐために INT 信号はオープンコレクタに変更してあります。

<img alt="基板イメージ" src="https://github.com/buppu3/tnCart/blob/main/pics/tnCart_rev1_3d.png?raw=true" width="40%" /><img alt="スロットに装着したカートリッジ基板" src="https://github.com/buppu3/tnCart/blob/main/pics/tnCart_rev1_mounted.png?raw=true" width="40%" />

## たぶん動く機能
- 4MB 拡張 RAM
- NEXTOR と TF カード制御
- FM 音源カートリッジ(拡張 BASIC は未対応)
- PSG 音源の 3.5mmフォンジャック出力
- メガロムエミュレーション
- SCC 音源
- V9990 エミュレーション(「msx-samurai」,「MSXgl V9990サンプルの一部」,「TINY野郎氏のテックデモ」がそれなりに動く程度)

## 既知の不具合
- V9990 の VDPコマンド割り込み
- V9990 のビットマップモード時の右端表示異常
- V9990 の B4モードのアップスキャン処理
- V9990 の P1/P2 モード時の LMMV コマンド
- バスの状態によっては WS2812 が点灯してしまう

## 今後の予定
- PAC エミュレーション
- V9990 の VDP コマンド(LINE,SRCH等)
- V9990 のカーソル EOR 処理
- V9990 とアップスキャンのインターレース対応
- V9990 の B0(192x240) モード
- 回路と基板の修正(本体のクロックからPLLクロックを生成、WS2812を点灯しないようにする等)

## しばらく(もしくは永遠に)対応する予定がない機能
- V9990 の B5(640x400),B6(640x480)モード
- V9990 の画面補正機能(R#16)
- V9990 の漢字ROM
- HDMI による音声出力(ライセンス的に難しい)

## 使用モジュール
各機能の実装に下記モジュールを使用しています。
- PSG https://github.com/dnotq/ym2149_audio
- OPLL(VM2413) https://github.com/hra1129/one-chip-msx-kai/tree/main/source/pld/src/sound/opll/vm2413
- OPLL(IKAOPLL) https://github.com/ika-musume/IKAOPLL

## メモ
- ~~V9990 機能を有効にする際は、config.sv の ENABLE_V9990, ENABLE_V9990_CMD を 1 に、ENABLE_FM, ENABLE_PSG, ENABLE_SCC 等を 0 に変更してから論理合成してください。全ての機能を有効にした状態では回路の規模が大きくなるため、TangNano20K では合成できません。~~
- 現在のバージョンは TangNano20K にギリギリ収まるサイズに最適化したので ENABLE_V9990, ENABLE_V9990_CMD, ENABLE_FM, ENABLE_PSG, ENABLE_SCC はすべて ENABLE になっています。
- V9990 の映像は 720x480ドット(ピクセルクロック 27MHz) の DVI 信号で出力されます。接続するモニターやビデオキャプチャー機器によっては正常に動作しない可能性があります。
