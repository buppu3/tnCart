//
// tools.c
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

#include <string.h>
#include "types.h"
#include "tools.h"

/***********************************************
 * strcmpi
 ***********************************************/
int strcmpi(char *s0, char *s1)
{
    while(1)
    {
        char c0 = *s0++;
        char c1 = *s1++;

        if(c0 >= 'A' && c0 <= 'Z') c0 |= 0x20;
        if(c1 >= 'A' && c1 <= 'Z') c1 |= 0x20;

        if(c0 < c1) return -1;
        if(c0 > c1) return 1;

        if(c0 == '\0' || c1 == '\0') break;
    }
    return 0;
}

/***********************************************
 * 16進数文字->数値変換
 *  引数
 *    c             : 変換元文字
 * 戻り値
 *    0~15 : 成功
 *    -1   : 失敗
 ***********************************************/
int hexchar_to_int(char c)
{
    if(c >= '0' && c <= '9') return c - '0';
    if(c >= 'A' && c <= 'F') return c - 'A' + 10;
    if(c >= 'a' && c <= 'f') return c - 'a' + 10;
    return -1;
}

/***********************************************
 * スロット番号変換
 *  引数
 *    result        : 結果格納バッファ
 *    p             : 変換元文字列
 * 戻り値
 *    0  : 成功
 *    !0 : 失敗
 ***********************************************/
int get_sltnum(uint8_t *result, char *p)
{
    uint8_t nibble[2];
    int len = 0;

    while(*p != '\0')
    {
        int n = hexchar_to_int(*p);
        if(n < 0) return -1;
        if(n > 3) return -1;

        if(len < 2) nibble[len] = n;

        len++;
        p++;
    }

    uint8_t sltnum;
    if(len == 1)
    {
        sltnum = nibble[0];
    }
    else if(len == 2)
    {
        sltnum = 0x80 | (nibble[1] << 2) | nibble[0];
    }
    else
    {
        return -1;
    }

    if(result != NULL) *result = sltnum;

    return 0;
}

/***********************************************
 * HEX 値変換
 *  引数
 *    result        : 結果格納バッファ
 *    p             : 変換元文字列
 *    width         : 最大文字列長
 * 戻り値
 *    0  : 成功
 *    !0 : 失敗
 ***********************************************/
int get_hex(uint32_t *result, char *p, int width)
{
    uint16_t val = 0;
    int count = 0;

    while(1)
    {
        // 文字取得
        char c = *p++;

        // 終端チェック
        if(c == '\0') break;

        // 桁数チェック
        if(count >= width) return -1;

        // 変換
        int n = hexchar_to_int(c);
        if(n >= 0)
        {
            val <<= 4;
            val |= n;
        }
        else
        {
            return -1;
        }
    }    

    return 0;
}

/***********************************************
 * キーワード検索
 *  引数
 *    result        : 結果格納バッファ
 *    tbl           : キーワードテーブル
 *    keyword       : 検索するキーワード
 * 戻り値
 *    0  : キーワードが見つかった
 *    !0 : キーワードが見つからない
 ***********************************************/
int search_keyword(VOID_PTR_t *result, KEYWORD_PARAM_t *tbl, char *keyword)
{
    KEYWORD_PARAM_t *p = tbl;

    while(p->keyword != NULL)
    {
        if(strcmpi(keyword, p->keyword) == 0)
        {
            if(result != NULL) *result = p->param;
            return 0;
        }

        p++;
    }
    return -1;
}


char *slot_to_str(char *buff, size_t size, uint8_t sltnum)
{
    if(size <= 0) return buff;
    *buff = '\0';
    if(sltnum & 0x80)
    {
        if(size >= 5)
        {
            buff[0] = '#';           
            buff[1] = '0' + (sltnum & 3);
            buff[2] = '-';
            buff[3] = '0' + ((sltnum >> 2) & 3);
            buff[4] = '\0';
        } 
    }
    else
    {
        if(size >= 3)
        {
            buff[0] = '#';           
            buff[1] = '0' + (sltnum & 3);
            buff[2] = '\0';
        } 
    }
    return buff;
}
