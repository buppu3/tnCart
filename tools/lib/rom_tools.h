//
// rom_tools.h
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

#ifndef _INCLUDE_ROM_TOOLS_H_
#define _INCLUDE_ROM_TOOLS_H_

#include "..\..\lib\types.h"

typedef struct {
    uint16_t    addr;
    uint8_t     init_val;
    uint8_t     reserved;
} ROM_ATTR_BANK_t;

typedef const struct {
    uint8_t         flags;
    uint8_t         val_mask;
    uint16_t        addr_mask;
    ROM_ATTR_BANK_t bank[4];
    char            *name;
} ROM_ATTR_t;

typedef ROM_ATTR_t *ROM_ATTR_PTR_t;

#define FLAG_WRITE_PROTECT      (1<<0)
#define FLAG_BANK_SIZE          (1<<1)
#define FLAG_CS1_MASK           (1<<2)
#define FLAG_CS2_MASK           (1<<3)
#define FLAG_SCC                (1<<4)
#define FLAG_ENABLE_CONTINUOUS  (1<<6)
#define FLAG_ENABLE             (1<<7)


void slot_select_p1(uint8_t sltnum);
void slot_select_p2(uint8_t sltnum);
void wrtslt(uint8_t sltnum, uint16_t addr, uint8_t data);
uint8_t rdslt(uint8_t sltnum, uint16_t addr);
void set_bank1_reg(uint8_t sltnum, uint8_t num);
void unlock_megarom_configure(uint8_t sltnum);
void lock_megarom_configure(uint8_t sltnum);
void rom_attr_xfer(uint8_t sltnum, ROM_ATTR_PTR_t rom_attr);
void init_bank_reg(uint8_t sltnum, ROM_ATTR_PTR_t rom_attr);
void clear_rom(uint8_t sltnum);
void xfer_memory(uint8_t sltnum, VOID_PTR_t dst, VOID_PTR_t src, size_t size);
uint32_t get_sdram_address(uint8_t sltnum);

#endif