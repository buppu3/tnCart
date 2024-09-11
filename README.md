# tnCart

TangNano20K を搭載した MSX 用カートリッジ

WonderTANG 対応版は [tnCartWonder](https://github.com/herraa1/tnCartWonder) をご参照ください。


## カートリッジ基板
回路は WonderTANG V1.01c のピンアサインとほぼ同じ(MSEL0_33 と MSEL1_33 が逆みたいです)で、バッファ IC は2電源タイプに変更してます。
また、信号の衝突を防ぐために INT 信号はオープンコレクタに変更してあります(WonderTANG V1.02d 相当)。

<img alt="基板イメージ" src="https://github.com/buppu3/tnCart/blob/main/pics/tnCart_rev1_3d.png?raw=true" width="40%" /><img alt="スロットに装着したカートリッジ基板" src="https://github.com/buppu3/tnCart/blob/main/pics/tnCart_rev1_mounted.png?raw=true" width="40%" />

## たぶん動く機能
- 4MB 拡張 RAM
- NEXTOR と TF カード制御
- FM 音源カートリッジ(拡張 BASIC は未対応)
- PSG 音源の 3.5mmフォンジャック出力
- メガロムエミュレーション
- SCC 音源
- PAC 機能(まだデータ保持機能が実装されていませんので、電源を切るとデータは消えます)
- V9990 エミュレーション(「[msx-samurai](https://github.com/albs-br/msx-samurai)」,「[MSXgl](https://github.com/aoineko-fr/MSXgl) V9990サンプルの一部」,「[TINY野郎氏のテックデモ](https://www.youtube.com/watch?v=I6kXyMaED0s)」がそれなりに動く程度)

https://github.com/user-attachments/assets/6ccc81ad-7539-472d-90ff-44e20a4ad2ab

https://github.com/user-attachments/assets/eceabaee-c464-4074-b1bb-01007c4406e5

https://github.com/user-attachments/assets/5c7b5b81-0413-4705-99fa-486552f4d58d

https://github.com/user-attachments/assets/f6615e37-0041-4baa-8b7d-7cd3aba46d73

## 今後の予定
- PAC データを FLASH で保持
- V9990 のカーソル EOR 処理
- V9990 の B0(192x240) モード
- 回路と基板の修正(WS2812を点灯しないようにする等)

## しばらく(もしくは永遠に)対応する予定がない機能
- V9990 の B5(640x400),B6(640x480)モード
- V9990 の画面補正機能(R#16)
- V9990 の漢字ROM
- HDMI による音声出力(ライセンス的に難しい)

## インストール方法
### ファイルのダウンロード
下記の3ファイルをダウンロードしてください。拡張子の .rom は .bin へリネームして保存してください。

- [tnCart_board_rev1.fs](https://github.com/buppu3/tnCart/blob/main/rtl/impl/pnr/tnCart_board_rev1.fs)
- [fmbios.rom](https://github.com/buppu3/tnCart/blob/main/roms/fmbios/bin/fmbios.rom)
- Nextor 公式( https://github.com/Konamiman/Nextor/releases )で配布されている "Nextor-2.1.2.MegaFlashSDSCC.1-slot.ROM"

### フラッシュ書き込みの準備(Windows)
tnCart カートリッジを MSX へ差し込まずに USB-C コネクタを使って PC と接続してください。
**tnCart と PC を接続したまま MSX へカートリッジを差し込むと、MSX や PC が故障する可能性がありますのでご注意ください。**
- GUI 版 GowinProgrammer を使用する場合は、tnCart と PC を接続後に GowinProgrammer を起動してください。
- programmer_cli.exe を使用する場合は、programmer_cli.exe があるディレクトリにカレントディレクトリを変更してください。

### ビットストリームの書き込み
"exFlash Erase,Program thru GAO-Bridge" で 0x000000~ に書き込みます。
~~~Shell
programmer_cli -d GW2AR-18C -r 36 -f download\tnCart_board_rev1.fs
~~~

### Nextor カーネルの書き込み
"exFlash C Bin Erase,Program thru GAO-Bridge" で 0x100000~ に書き込みます。
~~~Shell
programmer_cli -d GW2AR-18C -r 38 --spiaddr 0x100000 -f \download\Nextor-2.1.2.MegaFlashSDSCC.1-slot.bin
~~~

### FM-BIOS の書き込み
"exFlash C Bin Erase,Program thru GAO-Bridge" で 0x120000~ に書き込みます。
~~~Shell
programmer_cli -d GW2AR-18C -r 38 --spiaddr 0x120000 -f \download\fmbios.bin
~~~

### 起動
すべてのファイルの書き込みが完了したら、USB-C ケーブルを外し、MSX のカートリッジスロットへ差し込んでください。
カートリッジを挿入後、MSX の電源を入れてください(tnCart を使うと MSX の起動が 1秒程遅くなります)。

## 機能のカスタマイズ
機能の設定、メモリ配置は config.sv で変更できます。ファイルを変更後、GowinSynthesis でビットストリームを合成してください。合成時、機能の有無でタイミング制約ファイル(sdcファイル)がエラーになりますので、適宜修正してください。

### フラッシュメモリ
FLASH_ADDR_, FLASH_SIZE_ パラメータで各機能に使われるフラッシュメモリのアドレスとサイズを設定できます。

### SDRAM
RAM_ADDR_ パラメータで各機能に使われる RAM のアドレスを設定できます。

### 音量バランス
ATT_EXT_ パラメータで 3.5mm フォンジャック出力の調整、ATT_INT_ パラメータで本体音声の調整ができます。

| パラメータ                                  | 内容                            |
| ---                                        | ---                             |
| ATT_EXT_PSG_MUL<br/>ATT_EXT_PSG_DIV           | PSG 音源 3.5mm フォンジャック出力 |
| ATT_EXT_FM_MUL<br/>ATT_EXT_FM_DIV             | FM 音源 3.5mm フォンジャック出力  |
| ATT_EXT_MEGAROM_MUL<br/>ATT_EXT_MEGAROM_DIV   | SCC 音源 3.5mm フォンジャック出力 |
| ATT_INT_FM_MUL<br/>ATT_INT_FM_DIV             | FM 音源 本体出力                 |
| ATT_INT_MEGAROM_MUL<br/>ATT_INT_MEGAROM_DIV   | SCC 音源 本体出力                |

### 機能の ON/OFF
ENABLE_* パラメータで各機能の ENABLE/DISABLE を設定できます。
| パラメータ       | 内容                                                                     |
| ---             | ---                                                                      |
| ENABLE_MEGAROM  | メガロムエミュレータおよび SCC 機能の有効(ENABLE)/無効(DISABLE)を設定します。 |
| ENABLE_FM       | FM 音源および PAC 機能の有効(ENABLE_IKAOPLL または ENABLE_VM2413)/無効(DISABLE)を設定します。 |
| ENABLE_NEXTOR   | NEXTOR および TF カード機能の有効(ENABLE)/無効(DISABLE)を設定します。 |
| ENABLE_RAM      | 拡張 4MB RAM 機能の有効(ENABLE)/無効(DISABLE)を設定します。 |
| ENABLE_PSG      | PSG 出力機能の有効(ENABLE)/無効(DISABLE)を設定します。 |
| ENABLE_SCC      | SCC 出力機能の有効(ENABLE)/無効(DISABLE)を設定します。 |
| ENABLE_V9990<br/>ENABLE_V9990_CMD | V9990 エミュレータの有効(ENABLE)/無効(DISABLE)を設定します。|
| ENABLE_SCANLINE | アップスキャン時に走査線の隙間あり(ENABLE)/隙間なし(DISABLE)を設定します。 |

~~V9990 機能を有効にする際は、config.sv の ENABLE_V9990, ENABLE_V9990_CMD を 1 に、ENABLE_FM, ENABLE_PSG, ENABLE_SCC 等を 0 に変更してから論理合成してください。全ての機能を有効にした状態では回路の規模が大きくなるため、TangNano20K では合成できません。~~

現在のバージョンは TangNano20K にギリギリ収まるサイズに最適化したので ENABLE_V9990, ENABLE_V9990_CMD, ENABLE_FM, ENABLE_PSG, ENABLE_SCC はすべて ENABLE になっています。

## 使用モジュール
各機能の実装に下記モジュールを使用しています。
- PSG https://github.com/dnotq/ym2149_audio
- OPLL(VM2413) https://github.com/hra1129/one-chip-msx-kai/tree/main/source/pld/src/sound/opll/vm2413
- OPLL(IKAOPLL) https://github.com/ika-musume/IKAOPLL

## メモ
- V9990 の映像は 720x480ドット(ピクセルクロック約27MHz) の DVI 信号で出力されます。接続するモニターやビデオキャプチャー機器によっては正常に動作しない可能性があります。
- V9990 の VRAM アクセス方法は実物とかなり違います。実チップは別々のアドレスで 8bit アクセスできる VRAM バスを2つ持っていますが、TangNano20k ではそれを実装するのが難しいので 32bit 単位で VRAM を操作することで V9990 とほぼ同等のメモリ帯域(BMLL転送で 3MB/sec 位?)を実現しています。TangNano20k の CLS 使用量が大きくなってしまうのは、たぶんこれが原因です。
