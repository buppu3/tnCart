# tnCart
TangNano20K を搭載した MSX 用カートリッジ。WonderTANG 対応版は [tnCartWonder](https://github.com/herraa1/tnCartWonder) をご参照ください。

- [カートリッジ基板](#カートリッジ基板)
- [たぶん動く機能](#たぶん動く機能)
- [今後の予定](#今後の予定)
- [対応する予定がない機能](#対応する予定がない機能)
- [使用モジュール](#使用モジュール)
- [メモ](#メモ)

## 使い方

- [FPGAビットストリーム、BIOSイメージのインストール方法](https://github.com/buppu3/tnCart/blob/main/doc/flash.md)
- [メガロムエミュレータの使い方](https://github.com/buppu3/tnCart/blob/main/doc/megarom.md)
- [機能のカスタマイズ](https://github.com/buppu3/tnCart/blob/main/doc/config.md)

## カートリッジ基板
回路は WonderTANG V1.01c のピンアサインとほぼ同じ(MSEL0_33 と MSEL1_33 が逆みたいです)で、バッファ IC は2電源タイプに変更してます。
また、信号の衝突を防ぐために INT 信号はオープンコレクタに変更してあります(WonderTANG V1.02d 相当)。

<img alt="基板イメージ" src="https://github.com/buppu3/tnCart/blob/main/pics/tnCart_rev1_3d.png?raw=true" width="40%" /><img alt="スロットに装着したカートリッジ基板" src="https://github.com/buppu3/tnCart/blob/main/pics/tnCart_rev1_mounted.png?raw=true" width="40%" />

## たぶん動く機能
- 4MB 拡張 RAM
- NEXTOR と TF カード制御
- メガロムエミュレーション
- SCC/SCC-I 音源
- FM 音源(OPLL)カートリッジ(拡張 BASIC は未対応)
- SCC + OPLL + PSG 音源の 3.5mmフォンジャック出力
- PAC 機能(まだデータ保持機能が実装されていませんので、電源を切るとデータは消えます)
- V9990 エミュレーション(「[msx-samurai](https://github.com/albs-br/msx-samurai)」,「[MSXgl](https://github.com/aoineko-fr/MSXgl) V9990サンプルの一部」,「[TINY野郎氏のテックデモ](https://www.youtube.com/watch?v=I6kXyMaED0s)」がそれなりに動く程度)

### MSXglサンプル
https://github.com/user-attachments/assets/6ccc81ad-7539-472d-90ff-44e20a4ad2ab

### msx-samurai
https://github.com/user-attachments/assets/eceabaee-c464-4074-b1bb-01007c4406e5

### TINY野郎氏のテックデモ1
https://github.com/user-attachments/assets/5c7b5b81-0413-4705-99fa-486552f4d58d

### TINY野郎氏のテックデモ2
https://github.com/user-attachments/assets/f6615e37-0041-4baa-8b7d-7cd3aba46d73

## 今後の予定
- PAC データを FLASH で保持
- V9990 のカーソル EOR 処理
- V9990 の B0(192x240) モード
- 回路と基板の修正(WS2812を点灯しないようにする等)

## 対応する予定がない機能
下記の機能は、しばらく(もしくは永遠に)対応する予定がありません
- V9990 の B5(640x400),B6(640x480)モード
- V9990 の画面補正機能(R#16)
- V9990 の漢字ROM
- HDMI による音声出力(ライセンス的に難しい)

## 使用モジュール
各機能の実装に下記モジュールを使用しています。
- PSG https://github.com/dnotq/ym2149_audio
- OPLL(VM2413) https://github.com/hra1129/one-chip-msx-kai/tree/main/source/pld/src/sound/opll/vm2413
- OPLL(IKAOPLL) https://github.com/ika-musume/IKAOPLL
- SCC(IKASCC) https://github.com/ika-musume/IKASCC

## メモ
- V9990 の映像は 720x480ドット(ピクセルクロック約27MHz) の DVI 信号で出力されます。接続するモニターやビデオキャプチャー機器によっては正常に動作しない可能性があります。
- V9990 の VRAM アクセス方法は実物とかなり違います。実チップは別々のアドレスで 8bit アクセスできる VRAM バスを2つ持っていますが、TangNano20k ではそれを実装するのが難しいので 32bit 単位で VRAM を操作することで V9990 とほぼ同等のメモリ帯域(BMLL転送で 3MB/sec 位?)を実現しています。TangNano20k の CLS 使用量が大きくなってしまうのは、たぶんこれが原因です。
