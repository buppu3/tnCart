## メガロムエミュレータの使い方
メガロムエミュレータを利用する時は、tncrom コマンドを使用して ROM イメージを tnCart のメモリに転送する必要があります。

### tncrom のダウンロード
[tncrom.com](https://github.com/buppu3/tnCart/raw/main/tools/tncrom/bin/TNCROM.COM)をダウンロードし、Nextor をセットアップしたストレージにコピーしてください。

### ROM イメージ転送
Nextor を起動し、tncrom を実行してください。
~~~Shell
tncrom -T [ROMタイプ識別子] -R -O [イメージファイルのパス]
~~~

- -R オプションを指定するとROMイメージを転送後に MSX にリセットをかけます。
- -O オプションを指定するとリセットでメガロムエミュレータを無効にします(-O が未指定時は MSX の電源を OFF にするまでメガロムエミュレータが有効)。
- -T オプションで ROM のタイプを指定します。
- -N オプションでイメージファイルの転送を行いません。

ROMタイプに指定できる識別子は下記の通りです。
| ROMタイプ識別子 | ROMタイプ |
| --- | --- |
| 32K | 32KB ROM |
| 16K | 16KB ROM(ページ1) |
| 16K2 | 16KB ROM(ページ2) |
| ASCII16 | メガロム ASCII 16KB バンク |
| ASCII8 | メガロム ASCII 8KB バンク |
| KONAMI | メガロム コナミ 8KB バンク(SCC音源有効) |
| KONAMI_SCC_I | メガロム コナミ 8KB バンク(SCC-I有効) |
| KONAMI_WO_SCC | メガロム コナミ 8KB バンク(SCC音源無効) |
| R-TYPE | メガロム R-TYPE |

### コマンドラインの例
激突ペナントレース
~~~Shell
tncrom -T KONAMI -R -O GEKIPENA.ROM
~~~

R-TYPE
~~~Shell
tncrom -T R-TYPE -R -O R-TYPE.ROM
~~~

msx-samurai
~~~Shell
tncrom -T ASCII16 -R -O SAMURAI.ROM
~~~

MSXgl V9990 sample
~~~Shell
tncrom -T 32K -R -O S_V9990.ROM
~~~

TINY野郎氏の V9990 テックデモ
~~~Shell
tncrom -T ASCII16K -R -O DEMO9990.ROM
~~~

### SCC を有効にする
SCC を有効にする
~~~Shell
tncrom -T KONAMI -N
~~~

SCC-I を有効にする
~~~Shell
tncrom -T KONAMI_SCC_I -N
~~~

### その他
音楽プレーヤーや SofaRun 等を頻繁に利用する場合は、AUTOEXEC.BAT に "tncrom -T KONAMI_SCC_I -N" を追加すると便利です。
