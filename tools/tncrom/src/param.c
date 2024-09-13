//
// param.c
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

#include <stdio.h>
#include <string.h>
#include "..\..\lib\tools.h"
#include "param.h"
#include "message.h"

static int is_empty(char *p)
{
    while(*p != '\0')
    {
        if(*p++ > ' ') return 0;
    }
    return 1;
}

/***********************************************
 * パラメータ初期化
 *  引数
 *    param     : パラメータ構造体
 ***********************************************/
void init_main_param(MAIN_PARAM_t *param)
{
    memset(param, 0, sizeof(MAIN_PARAM_t));
    param->sltnum = 0xFF;
}

/***********************************************
 * コマンドラインのチェック
 *  引数
 *    param     : パラメータ構造体
 *    argc      :
 *    argv      :
 *  戻り値
 *    0  : 成功
 *    !0 : 失敗
 ***********************************************/
int parse_param(MAIN_PARAM_t *param, int argc, char *argv[])
{
    uint8_t next_state = 0;

    init_main_param(param);

    for(int i = 1; i < argc; i++)
    {
        uint8_t state = 0;
        if(argv[i][0] == '/' || argv[i][0] == '-')
        {
            //
            // オプションスイッチ処理
            //
            state = argv[i][1];
            if(state >= 'a' && state <= 'z') state &= ~0x20;

            // パラメータ付き?
            switch(state)
            {
                case 'T':
                case 'S':
                    next_state = state;
                    state = 0;
                    break;
            }
        }
        else if(next_state != 0)
        {
            //
            // 次回処理が指定されていた場合
            //
            state = next_state;                     // 今回処理する内容
            next_state = 0;                         // 次回は何もしない
        }
        else
        {
            //
            // オプションスイッチなしで指定されたパラメータはROMファイル名として処理する
            //
            if(!is_empty(argv[i]))
            {
                if(param->rom_file[0] != '\0')
                {
                    printf(MSG_PARAM_MULTI_FILE);
                    return 1;
                }
                if(strlen(argv[i]) >= sizeof(param->rom_file))
                {
                    printf(MSG_PARAM_PATH_TOO_LONG, argv[i]);
                    return 1;
                }
                strncpy(param->rom_file, argv[i], sizeof(param->rom_file));
                state = 0;
                next_state = 0;
            }
        }

        switch(state)
        {
            //
            // 何もしない
            //
            case 0:
                break;

            //
            // ヘルプ
            //
            case 'H':
                param->help_flag = 1;
                break;

            //
            // ROM イメージ転送しない
            //
            case 'N':
                param->nofile_flag = 1;
                break;

            //
            // 設定ファイルを使用
            //
            case 'C':
                param->use_conf_file = 1;
                break;

            //
            // ハードウェアリセットまで有効
            //
            case 'O':
                param->once_flag = 1;
                break;

            //
            // 終了時にリセット
            //
            case 'R':
                param->reset_flag = 1;
                break;

            //
            // ROM タイプ指定
            //
            case 'T':
                if(strlen(argv[i]) >= sizeof(param->rom_type))
                {
                    printf(MSG_UNKNOWN_ROM_TYPE, argv[i]);
                    return 1;
                }
                strncpy(param->rom_type, argv[i], sizeof(param->rom_type));
                break;

            //
            // スロット番号指定
            //          
            case 'S':
                if(get_sltnum(&param->sltnum, argv[i]))
                {
                    printf(MSG_PARAM_INVALID_SLOT, argv[i]);
                    return 1;
                }
                break;

            //
            // 未定義のオプション
            //            
            default:
                printf(MSG_PARAM_UNKNOWN, state);
                return 1;
        }
    }

    return 0;
}
