//
// main.c
//
// BSD 3-Clause License
// 
// Copyright (c) 2024, Shinobu Hashimoto
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// 
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
// 
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
// 
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

// zcc +msx -subtype=msxdos -o../bin/TNCROM.COM main.c ..\..\lib\bdos.c ..\..\lib\tools.c ..\..\lib\rom_tools.c ..\..\lib\reboot.c rom_table.c config.c param.c

#include <stdio.h>
#include <string.h>
#include "..\..\lib\types.h"
#include "..\..\lib\bdos.h"
#include "..\..\lib\tools.h"
#include "..\..\lib\rom_tools.h"
#include "..\..\lib\reboot.h"
#include "rom_table.h"
#include "config.h"
#include "param.h"
#include "message.h"

#define VERSION (6)


static MAIN_PARAM_t main_param;     // パラメータ
static BDOS_FILE_t rom_file;        // ROM ファイルアクセス用

//
// データ書き込み用の ROM 設定
//
static const ROM_ATTR_t ROM_ATTR_ASCII16_WO_WP = {
    (uint8_t)(FLAG_ENABLE | FLAG_BANK_SIZE),
    (uint8_t)0xFF,
    (uint16_t)0xF800,
    {
        { (uint16_t)0x6000, 0, 0 },
        { (uint16_t)0x7000, 0, 0 },
        { (uint16_t)0xFFFF, 0, 0 },
        { (uint16_t)0xFFFF, 0, 0 }
    },
    "---"
};

/***********************************************
 * ROM を有効にする
 *  引数
 *    sltnum    : スロット番号
 *    enable    : 有効/無効フラグ
 *    enable_continuous : ハードウェアリセットで enable フラグをクリアするかどうか
 ***********************************************/
static void set_rom_enable(uint8_t sltnum, int enable, int enable_continuous)
{
    unlock_megarom_configure(sltnum);
    uint8_t flags = rdslt(sltnum, 0x0C);
    flags &= ~(FLAG_ENABLE | FLAG_ENABLE_CONTINUOUS);
    if(enable) flags |= FLAG_ENABLE;
    if(enable_continuous) flags |= FLAG_ENABLE_CONTINUOUS;
    wrtslt(sltnum, 0x0C, flags);
    lock_megarom_configure(sltnum);
}

/***********************************************
 * 1バンク分(16KB)転送
 *  引数
 *    sltnum    : スロット番号
 *    bank      : バンク番号
 *    file      : 転送元のファイル
 *  戻り値
 *    0  : 成功
 *    !0 : 失敗
 ***********************************************/
static int xfer_bank(uint8_t sltnum, uint8_t bank, BDOS_FILE_t *file, uint32_t pending)
{
    int res;
    uint16_t addr = (uint16_t)0x8000;
    uint16_t readed;

    // バンク切り替え
    set_bank1_reg(sltnum, bank);

    for(uint8_t i = 0; i < (uint8_t)(16384 / 128); i++)
    {
        if (pending > 0) {
            // 128バイト読み出し
            if(0 != (res = bdos_fread(file, &readed))){
                printf(MSG_ERR_FILEREAD);
                return res;
            }

            // データを転送
            xfer_memory(sltnum, (VOID_PTR_t)addr, file->buffer, readed);

            // 次の準備
            addr += (uint16_t)readed;

            pending -= readed;
        } else
            break;
    }

    return 0;
}

/***********************************************
 * ファイル転送
 *  引数
 *    sltnum    : スロット番号
 *    file      : 転送元ファイルのファイル
 *  戻り値
 *    0  : 成功
 *    !0 : 失敗
 ***********************************************/
static int xfer_file(uint8_t sltnum, BDOS_FILE_t *file)
{
    int res;
    uint8_t bank = 0;
    uint32_t size;

    // ファイルサイズを得る    
    if(0 != (res = bdos_file_size(file, &size)))
    {
        printf(MSG_ERR_GETFILESIZE);
        return res;
    }
    
    // バンク1のバンクレジスタを設定時にバンク0のデータが化けるので、Bank0を予め最終バンクに切り替え
    uint8_t last_bank = ((size - (uint32_t)1) >> 14) & 255;
    set_bank0_reg(sltnum, last_bank);

    while(size > (uint32_t)0)
    {
        printf(MSG_PROGRESS, bank);

        // 16KB 転送
        if(0 != (res = xfer_bank(sltnum, bank, file, size))) return res;

        // 次の準備
        bank++;

        // support less than 16K ROMs
        uint16_t remaining = (size >= 16384)? 16384 : size;
        size -= remaining;
    }    

    printf(MSG_PROGRESS_TERM);
    return 0;
}

/***********************************************
 * イメージファイル転送
 *  引数
 *    sltnum    : スロット番号
 *    rom_attr  : ROM 属性
 *    path      : 転送元ファイルのファイル
 *  戻り値
 *    0  : 成功
 *    !0 : 失敗
 ***********************************************/
static int load_rom_image(uint8_t sltnum, ROM_ATTR_PTR_t rom_attr, char *path)
{
    int res = 0;

    if(path != NULL)
    {
        // ファイルを開く
        if(0 != (res = bdos_fopen(&rom_file, path)))
        {
            printf(MSG_ERR_FILEOPEN, path);
            return res;
        }

        // ROM 書き込み許可
        rom_attr_xfer(sltnum, &ROM_ATTR_ASCII16_WO_WP);

        // ファイルを転送
        res = xfer_file(sltnum, &rom_file);

        // ファイルを閉じる
        bdos_fclose(&rom_file);
    }

    if(res != 0)
    {
        // 転送失敗時は誤動作防止のために ROM ヘッダを消去
        clear_rom(sltnum);

        // ROM 領域への書き込み禁止
        rom_attr = &ROM_ATTR_ASCII16;
        rom_attr_xfer(sltnum, rom_attr);
    }
    else
    {
        // バンク切り替えなし ROM で正しくデータが読めるようにバンク 0 を戻す
        rom_attr_xfer(sltnum, &ROM_ATTR_ASCII16);
        set_bank0_reg(sltnum, 0);

        // ROM 属性設定
        rom_attr_xfer(sltnum, rom_attr);

        // SCC-I モードレジスタ初期化
        if(rom_attr->flags & FLAG_SCC_I)
        {
            wrtslt(sltnum, 0xBFFE, 0x00);
        }
    }

    // バンクレジスタ初期設定
    init_bank_reg(sltnum, rom_attr);

    return res;
}

/***********************************************
 * カートリッジチェック
 *  引数
 *    sltnum    : チェックするスロット番号
 *  戻り値
 *    0  : 成功
 *    !0 : 失敗
 ***********************************************/
int check_cartridge(uint8_t sltnum)
{
    int res = -1;
    uint8_t save[4];

#asm
    DI
#endasm

    // 元データを取得
    for(uint16_t addr = 0; addr < sizeof(save); addr++) save[addr] = rdslt(sltnum, addr);

    // RAM かどうかをチェックする
    wrtslt(sltnum, 0, 0xAA);
    if(rdslt(sltnum, 0) == 0xAA) goto err;
    wrtslt(sltnum, 0, 0x55);
    if(rdslt(sltnum, 0) == 0x55) goto err;

    // UNLOCK して読み出しデータが変化するかチェック
    wrtslt(sltnum, 0, 0xAB);
    wrtslt(sltnum, 1, 0xCD);
    wrtslt(sltnum, 2, 0x98);
    wrtslt(sltnum, 3, 0x76);
    if(rdslt(sltnum, 0) != 0xAB) goto err;
    if(rdslt(sltnum, 1) != 0xCD) goto err;
    if(rdslt(sltnum, 2) != 0x98) goto err;
    if(rdslt(sltnum, 3) != 0x76) goto err;

    // LOCK して読み出しデータが変化するかチェック
    wrtslt(sltnum, 0, 0x00);
    wrtslt(sltnum, 1, 0x00);
    wrtslt(sltnum, 2, 0x00);
    wrtslt(sltnum, 3, 0x00);
    if(rdslt(sltnum, 0) == 0xAB) goto err;
    if(rdslt(sltnum, 1) == 0xCD) goto err;
    if(rdslt(sltnum, 2) == 0x98) goto err;
    if(rdslt(sltnum, 3) == 0x76) goto err;

    //
    res = 0;

err:
    // 元データに戻す
    for(uint16_t addr = 0; addr < sizeof(save); addr++) wrtslt(sltnum, addr, save[addr]);

#asm
    EI
#endasm

    return res;
}

/***********************************************
 * カートリッジを探す
 *  引数
 *    sltnum    : 見つかったスロット番号を格納する変数のポインタ
 *  戻り値
 *    0  : 成功
 *    !0 : 失敗
 ***********************************************/
int search_cartridge(uint8_t *sltnum)
{
    for(uint8_t primary = 0; primary < 4; primary++)
    {
        if(*(uint8_t*)(0xFCC1 + primary) & 0x80)
        {
            for(uint8_t secondary = 0; secondary < 4; secondary++)
            {
                uint8_t slt = 0x80 | primary | (secondary << 2);
                if(check_cartridge(slt) == 0)
                {
                    if(sltnum != NULL) *sltnum = slt;
                    return 0;
                }
            }
        }
        else
        {
            if(check_cartridge(primary) == 0)
            {
                if(sltnum != NULL) *sltnum = primary;
                return 0;
            }
        }
    }
    return -1;
}

/***********************************************
 * バージョン情報出力
 ***********************************************/
static void output_version(void)
{
    printf(MSG_VERSION, VERSION / 100, VERSION % 100);
}

/***********************************************
 * usage 出力
 ***********************************************/
static void output_usage(void)
{
    printf(MSG_USAGE);
}

/***********************************************
 * help 出力
 ***********************************************/
static void output_help(void)
{
    printf(MSG_HELP);
    KEYWORD_PARAM_PTR_t p = rom_attr_table;
    while(p->keyword != NULL)
    {
        printf("               %10s: %s\n", p->keyword, ((ROM_ATTR_PTR_t)p->param)->name);
        p++;
    }
}

/***********************************************
 * abort handler
 ***********************************************/
static void abort_handler(void)
{
    // 転送途中に中断した場合は ROM をクリアしてから終了
    rom_attr_xfer(main_param.sltnum, &ROM_ATTR_ASCII16_WO_WP);
    clear_rom(main_param.sltnum);
    rom_attr_xfer(main_param.sltnum, &ROM_ATTR_ASCII16);
    init_bank_reg(main_param.sltnum, &ROM_ATTR_ASCII16);
    bdos_term(BDOS_ERR_ABORT);
}

/***********************************************
 * main
 ***********************************************/
int main(int argc, char *argv[])
{
    char *rom_file = NULL;
    char *rom_type = NULL;
    ROM_ATTR_PTR_t rom_attr = NULL;

    // バージョン出力
    output_version();

    // コマンドラインをパース
    if(parse_param(&main_param, argc, argv)) return 1;

    // ヘルプ出力
    if(main_param.help_flag)
    {
        output_usage();
        output_help();
        return 0;
    }

    // ファイルが指定されていない場合
    if(!main_param.nofile_flag && main_param.rom_file[0] == '\0')
    {
        output_usage();
        return 1;
    }

    // コンフィグレーションファイルを指定している？
    if(main_param.use_conf_file)
    {
        // コンフィグレーションファイルから ROM ファイルパスを得る
        if(load_config_file(main_param.rom_file))
        {
            return 1;
        }

        // コンフィグレーションファイルで指定された ROM ファイルとタイプを使用
        rom_file = config.rom_file;
        rom_type = config.rom_type;
    }
    else
    {
        // コマンドラインから ROM ファイルを指定
        rom_file = main_param.rom_file;
    }

    // コマンドラインから ROM タイプを指定している場合
    if(main_param.rom_type[0] != '\0') rom_type = main_param.rom_type;

    // ROM タイプ名から属性を探す
    if(search_keyword((VOID_PTR_t*)&rom_attr, rom_attr_table, rom_type))
    {
        printf(MSG_UNKNOWN_ROM_TYPE, rom_type);
        return 1;
    }

    // コマンドラインでカートリッジスロットが指定されていない場合はカートリッジを探す
    if(main_param.sltnum == (uint8_t)0xFF)
    {
        if(search_cartridge(&main_param.sltnum))
        {
            printf(MSG_CARTRIDGE_NOT_FOUND);
            return 1;
        }
    }

    // ROM イメージファイルの転送
    char buff[8];
    printf(MSG_PROP_SLOT, slot_to_str(buff, sizeof(buff), main_param.sltnum));
    printf(MSG_PROP_ROM_FILE, rom_file);
    printf(MSG_PROP_ROM_TYPE, rom_attr->name);
    if(bdos_set_about_handler((uint16_t)abort_handler))
    {
        printf(MSG_HANDLER_ERROR);
        return 1;        
    }
    int res = load_rom_image(main_param.sltnum, rom_attr, main_param.nofile_flag ? NULL : rom_file);
    bdos_set_about_handler(0);

    if(res == 0)
    {
        set_rom_enable(main_param.sltnum, 1, !main_param.once_flag);
    }

    printf(MSG_COMPLETE);

    if(res == 0 && main_param.reset_flag)
    {
        printf(MSG_REBOOT);
        reboot();
    }

    return res;
}
