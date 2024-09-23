# FPGA ビットストリーム、BIOS イメージのインストール方法

## ファイルのダウンロード

下記の3ファイルをダウンロードしてください。拡張子の .rom は .bin へリネームして保存してください。

- [tnCart_board_rev1.fs](https://github.com/buppu3/tnCart/raw/main/rtl/impl/pnr/tnCart_board_rev1.fs)
- [fmbios.rom](https://github.com/buppu3/tnCart/raw/main/roms/fmbios/bin/fmbios.rom)
- Nextor 公式( https://github.com/Konamiman/Nextor/releases )で配布されている "Nextor-2.1.2.MegaFlashSDSCC.1-slot.ROM"

## Flash プログラム方法(Windows GUI)

### 準備
カートリッジが MSX から外れていることを確認し、TangNano20k の USB-C コネクタと PC の USB コネクタをケーブルで接続してください。
**tnCart と PC を接続したまま MSX へカートリッジを差し込むと、MSX や PC が故障する可能性がありますのでご注意ください。**

GowinProgrammer を起動してください。  

ケーブル選択表示がでますので、**SAVE**をクリック  
<img alt="ケーブル選択" src="https://github.com/buppu3/tnCart/blob/main/pics/doc/flash_000_cable_select.png?raw=true">
  
もし、この表示が出たら場合は USBの接続を確認して[Query/DetectCable]をクリックし、その次に[SAVE]をクリック  
<img alt="no usb" src="https://github.com/buppu3/tnCart/blob/main/pics/doc/flash_001_no_usb.png?raw=true">  
<img alt="DetectCable" src="https://github.com/buppu3/tnCart/blob/main/pics/doc/flash_002_detect_cable.png?raw=true">
  
**Scan Device**をクリックする  
<img alt="ScanDevice" src="https://github.com/buppu3/tnCart/blob/main/pics/doc/flash_003_scan_device.png?raw=true">
  
デバイス選択表示で[GWAR-18C]を選び[OK]をクリック  
<img alt="Device選択" src="https://github.com/buppu3/tnCart/blob/main/pics/doc/flash_004_device.png?raw=true">
  
### FPGA ビットストリームの書き込み

**Configure Device**をクリックし、設定を開きます  
<img alt="ConfigDevice" src="https://github.com/buppu3/tnCart/blob/main/pics/doc/flash_100_config_device.png?raw=true">
  
<img alt="ConfigDevice設定" src="https://github.com/buppu3/tnCart/blob/main/pics/doc/flash_101_config_param.png?raw=true">
  
| 項目 | 設定する内容 |
| --- | --- |
| AccessMode | External Flash Mode |
| Operation | exFlash Erase, Program thru GAO-Brige |
| Device | Generic Flash |
| StartAddress | 0x000000 |
| Filename | ...をクリックして、tnCart_board_rev1.fsを選択(使いたいビットストリームのファイルを選択) |

設定を変更したら、**Save**をクリック  
  
**Program/Configure**をクリックし、Flash へ Program します。  
<img alt="program" src="https://github.com/buppu3/tnCart/blob/main/pics/doc/flash_102_program.png?raw=true">
  
しばらく待つとフラッシュへのプログラムが完了します。  
<img alt="ログ" src="https://github.com/buppu3/tnCart/blob/main/pics/doc/flash_103_log.png?raw=true">

### Nextor カーネルの書き込み

**Configure Device**をクリックし、設定を開きます  
<img alt="ConfigDevice" src="https://github.com/buppu3/tnCart/blob/main/pics/doc/flash_100_config_device.png?raw=true">
  
<img alt="ConfigDevice設定" src="https://github.com/buppu3/tnCart/blob/main/pics/doc/flash_201_config_param.png?raw=true">
  
| 項目 | 設定する内容 |
| --- | --- |
| AccessMode | External Flash Mode |
| Operation | exFlash C Bin Erase, Program thru GAO-Brige |
| Device | Generic Flash |
| StartAddress | 0x100000 |
| Filename | ...をクリックして、Nextor-2.1.2MegaFlashSDSCC.1-slot.binを選択 |

**Save**をクリック  
  
**Program/Configure**をクリックし、Flash へ Program します。  
<img alt="program" src="https://github.com/buppu3/tnCart/blob/main/pics/doc/flash_102_program.png?raw=true">
  
しばらく待つとフラッシュへのプログラムが完了します。  
<img alt="ログ" src="https://github.com/buppu3/tnCart/blob/main/pics/doc/flash_203_log.png?raw=true">

### FM BIOS の書き込み

**Configure Device**をクリックし、設定を開きます  
<img alt="ConfigDevice" src="https://github.com/buppu3/tnCart/blob/main/pics/doc/flash_100_config_device.png?raw=true">
  
<img alt="ConfigDevice設定" src="https://github.com/buppu3/tnCart/blob/main/pics/doc/flash_301_config_param.png?raw=true">
  
| 項目 | 設定する内容 |
| --- | --- |
| AccessMode | External Flash Mode |
| Operation | exFlash C Bin Erase, Program thru GAO-Brige |
| Device | Generic Flash |
| StartAddress | 0x120000 |
| Filename | ...をクリックして、fmbios.binを選択 |

**Save**をクリック  
  
**Program/Configure**をクリックし、Flash へ Program します。  
<img alt="program" src="https://github.com/buppu3/tnCart/blob/main/pics/doc/flash_102_program.png?raw=true">
  
しばらく待つとフラッシュへのプログラムが完了します。  
<img alt="ログ" src="https://github.com/buppu3/tnCart/blob/main/pics/doc/flash_303_log.png?raw=true">

### 終了と起動

GowinProgrammer を終了し、TangNnano20kから USB ケーブルを外してください。  
MSX の電源が OFF であることを確認し、カートリッジを MSX へ差し込んでください。  
カートリッジが正しく差し込まれていることを確認したら、MSX の電源をONにします。  

## Flash プログラム方法(Windows CUI)

### 準備
カートリッジが MSX から外れていることを確認し、TangNano20k の USB-C コネクタと PC の USB コネクタをケーブルで接続してください。
**tnCart と PC を接続したまま MSX へカートリッジを差し込むと、MSX や PC が故障する可能性がありますのでご注意ください。**

コマンドプロンプトを起動し、programmer_cli.exe があるディレクトリにカレントディレクトリを変更してください。

### FPGA ビットストリームの書き込み
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

### 終了と起動
すべてのイメージの書き込みが完了したら、USB-C ケーブルを外し、tnCart を MSX のカートリッジスロットへ差し込んでください。
カートリッジを挿入後、MSX の電源を入れてください(tnCart を MSX に接続すると MSX の起動が 1秒程遅くなります)。
