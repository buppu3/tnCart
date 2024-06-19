## FM BIOS ROM

アプリケーションに OPLL を検出させるための ROM ファイルです。
拡張 BASIC や ROM 内蔵音色は使用できません。

ファイルの拡張子を全て .rom から .bin へ変更し、Gowin Programmer を使用して 120000h へ書き込んでください。

This is a ROM file that allows applications to detect OPLL.
When using OPLL, you need to write this ROM file to address 120000h using "Gowin Programmer".

This ROM does not support BASIC statements and instrument data read from the ROM.
Gowin Programmer will not work properly unless you change the ROM file extension to ".bin".
