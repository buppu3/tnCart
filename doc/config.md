## 機能のカスタマイズ
機能の設定、メモリ配置は config.sv で変更できます。ファイルを変更後、GowinSynthesis でビットストリームを合成してください。合成時、機能の有無でタイミング制約ファイル(sdcファイル)がエラーになりますので、適宜修正してください。

### フラッシュメモリ
FLASH_ADDR_, FLASH_SIZE_ パラメータで各機能に使われるフラッシュメモリのアドレスとサイズを設定できます。

### SDRAM
RAM_ADDR_ パラメータで各機能に使われる RAM のアドレスを設定できます。

### 音量バランス
ATT_EXT_ パラメータで 3.5mm フォンジャック出力の調整、ATT_INT_ パラメータで本体音声の調整ができます。  
MUL と DIV の比率で指定します。例えば出力を 0.5倍にするときは、MUL = 1, DIV = 2 を指定してください。

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
| ENABLE_MEGAROM  | メガロムエミュレータおよび SCC 機能の有効(ENABLE または ENABLE_MEGA_SCC または ENABLE_MEGA_SCC_I)/無効(DISABLE)を設定します。 |
| ENABLE_FM       | FM 音源および PAC 機能の有効(ENABLE_IKAOPLL または ENABLE_VM2413)/無効(DISABLE)を設定します。 |
| ENABLE_NEXTOR   | NEXTOR および TF カード機能の有効(ENABLE)/無効(DISABLE)を設定します。 |
| ENABLE_RAM      | 拡張 4MB RAM 機能の有効(ENABLE)/無効(DISABLE)を設定します。 |
| ENABLE_PSG      | PSG 出力機能の有効(ENABLE)/無効(DISABLE)を設定します。 |
| ENABLE_SCC      | SCC 出力機能の有効(ENABLE または ENABLE_IKASCC)/無効(DISABLE)を設定します。 |
| ENABLE_V9990<br/>ENABLE_V9990_CMD | V9990 エミュレータの有効(ENABLE)/無効(DISABLE)を設定します。|
| ENABLE_PAC_WRITE | PAC データをフラッシュへ記録するか(ENABLE)/記録しないか(DISABLE)を設定します。 |
| ENABLE_SCANLINE | アップスキャン時に走査線の隙間あり(ENABLE)/隙間なし(DISABLE)を設定します。 |

## 備考
~~V9990 機能を有効にする際は、config.sv の ENABLE_V9990, ENABLE_V9990_CMD を 1 に、ENABLE_FM, ENABLE_PSG, ENABLE_SCC 等を 0 に変更してから論理合成してください。全ての機能を有効にした状態では回路の規模が大きくなるため、TangNano20K では合成できません。~~

現在のバージョンは TangNano20K にギリギリ収まるサイズに最適化したので ENABLE_V9990, ENABLE_V9990_CMD, ENABLE_FM, ENABLE_PSG, ENABLE_SCC はすべて ENABLE になっています。  

Gowin Synthesis のバージョンで出力されるネットリストが違いますので、合成後は Time Analysis Report を確認した方がよいです(私は V1.9.9_x64で合成しています)。

~~IKASCC は 1chip MSX では MUX されたバスタイミングが合わないため動きません。~~

ENABLE_IKASCC 指定時は SCC-I 音源は使えません。

ENABLE_MEGAROM に ENABLE_MEGA_SCC または ENABLE_MEGA_SCC_I を指定すると tncrom.com を使用せずに SCC/SCC-I を有効にできます。
