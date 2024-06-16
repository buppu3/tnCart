# NEXTOR カーネルロムイメージ

Nextor を使用する場合は、Gowin Programmer で EEPROM の 100000h へカーネル ROM を書いてください。
公式で配布されている "Nextor-2.1.2.MegaFlashSDSCC.1-slot.ROM" を使用してください。
ファイルの拡張子を全て小文字で bin へ変更しないと Gowin Programmer が正常に動作しませんので注意してください。

When using Nextor, you must write the ROM file to address 100000h using "Gowin Programmer".
The current version works with the officially distributed ROM file "Nextor-2.1.2.MegaFlashSDSCC.1-slot.ROM".
Gowin Programmer will not work properly unless you change the ROM file extension to ".bin".
