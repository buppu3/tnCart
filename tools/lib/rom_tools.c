//
// rom_tools.c
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
#include "..\..\lib\types.h"
//#include "rom_table.h"
#include "rom_tools.h"

#define RAMAD1      (*(uint8_t*)0xF342)
#define RAMAD2      (*(uint8_t*)0xF343)

/***********************************************
 * Page1スロット切り替え
 ***********************************************/
void slot_select_p1(uint8_t sltnum)
{
#asm
    LD      IX, 2
    ADD     IX, SP
    LD      A, (IX + 0)
    LD      HL, 4000h
    CALL    0024h
#endasm
}

/***********************************************
 * Page2スロット切り替え
 ***********************************************/
void slot_select_p2(uint8_t sltnum)
{
#asm
    LD      IX, 2
    ADD     IX, SP
    LD      A, (IX + 0)
    LD      HL, 8000h
    CALL    0024h
#endasm
}

/***********************************************
 * 指定スロットへ書き込み
 *  引数
 *    sltnum    : スロット番号
 *    addr      : 書き込むアドレス
 *    data      : 書き込むデータ
 ***********************************************/
void wrtslt(uint8_t sltnum, uint16_t addr, uint8_t data)
{
#asm
    LD      IX, 2
    ADD     IX, SP
    LD      E, (IX+0)   ;data
    LD      L, (IX+2)   ;addr_l
    LD      H, (IX+3)   ;addr_h
    LD      A, (IX+4)   ;sltnum
    CALL    0014h
#endasm
}

/***********************************************
 * 指定スロットから読み出し
 *  引数
 *    sltnum    : スロット番号
 *    addr      : 読み出すアドレス
 *  戻り値
 *    読みだしたデータ
 ***********************************************/
uint8_t rdslt(uint8_t sltnum, uint16_t addr)
{
#asm
    LD      IX, 2
    ADD     IX, SP
    LD      L, (IX+0)   ;addr_l
    LD      H, (IX+1)   ;addr_h
    LD      A, (IX+2)   ;sltnum
    CALL    000Ch
    LD      H, 0
    LD      L, A
#endasm
}

/***********************************************
 * BANK#1 切り替え
 ***********************************************/
void set_bank1_reg(uint8_t sltnum, uint8_t num)
{
    wrtslt(sltnum, 0x7000, num);
}

/***********************************************
 * コンフィグレーションレジスタのロック解除
 *  引数
 *    sltnum    : スロット番号
 ***********************************************/
void unlock_megarom_configure(uint8_t sltnum)
{
    wrtslt(sltnum, 0x0000, 0xAB);    
    wrtslt(sltnum, 0x0001, 0xCD);    
    wrtslt(sltnum, 0x0002, 0x98);    
    wrtslt(sltnum, 0x0003, 0x76);    
}

/***********************************************
 * コンフィグレーションレジスタのロック
 *  引数
 *    sltnum    : スロット番号
 ***********************************************/
void lock_megarom_configure(uint8_t sltnum)
{
    wrtslt(sltnum, 0x0000, 0x00);    
    wrtslt(sltnum, 0x0001, 0x00);    
    wrtslt(sltnum, 0x0002, 0x00);    
    wrtslt(sltnum, 0x0003, 0x00);    
}

/***********************************************
 * ROM 属性を設定
 *  引数
 *    sltnum    : スロット番号
 *    rom_attr  : ROM 属性
 ***********************************************/
void rom_attr_xfer(uint8_t sltnum, ROM_ATTR_PTR_t rom_attr)
{
    uint8_t *p = (uint8_t*)rom_attr;

    unlock_megarom_configure(sltnum);
    for(uint16_t addr = 0x000C; addr < 0x0020; addr++)
    {
        wrtslt(sltnum, addr, *p++);
    }    
    lock_megarom_configure(sltnum);
}

/***********************************************
 * バンクレジスタ初期設定
 *  引数
 *    sltnum    : スロット番号
 *    rom_attr  : ROM 属性
 ***********************************************/
void init_bank_reg(uint8_t sltnum, ROM_ATTR_PTR_t rom_attr)
{
    for(int i = 0; i < 4; i++)
    {
        if(rom_attr->bank[i].addr != (uint16_t)0xFFFF)
        {
            wrtslt(sltnum, rom_attr->bank[i].addr, rom_attr->bank[i].init_val);
        }
    }
}

/***********************************************
 * ROM データクリア
 *  引数
 *    sltnum    : スロット番号
 ***********************************************/
void clear_rom(uint8_t sltnum)
{
    set_bank1_reg(sltnum, 1);   wrtslt(sltnum, 0x4000, 0);  wrtslt(sltnum, 0x6000, 0);
    set_bank1_reg(sltnum, 0);   wrtslt(sltnum, 0x4000, 0);  wrtslt(sltnum, 0x6000, 0);
}

/***********************************************
 * メモリ転送
 *  引数
 *    sltnum    : 転送先スロット番号
 *    dst       : 転送先アドレス
 *    src       : 転送元ポインタ
 *    size      : 転送サイズ
 ***********************************************/
void xfer_memory(uint8_t sltnum, VOID_PTR_t dst, VOID_PTR_t src, size_t size)
{
#asm
    DI

    LD      IX, 2
    ADD     IX, SP

    PUSH    IX
    LD      A, (IX + 6)     ; sltnum
    LD      HL, 8000h
    CALL    0024h
    POP     IX

    LD      C, (IX + 0)     ; size
    LD      B, (IX + 1)
    LD      L, (IX + 2)     ; src
    LD      H, (IX + 3)
    LD      E, (IX + 4)     ; dst
    LD      D, (IX + 5)
    LDIR

    LD      A, (0F343h)
    LD      HL, 8000h
    CALL    0024h

    EI
#endasm
}


uint32_t get_sdram_address(uint8_t sltnum)
{
    unlock_megarom_configure(sltnum);

    uint32_t addr =
         (uint32_t)rdslt(sltnum, 0x0008)        |
        ((uint32_t)rdslt(sltnum, 0x0009) <<  8) |
        ((uint32_t)rdslt(sltnum, 0x000A) << 16) |
        ((uint32_t)rdslt(sltnum, 0x000B) << 24);

    lock_megarom_configure(sltnum);

    return addr;
}
