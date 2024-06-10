//
// rom_table.c
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
#include "..\..\lib\tools.h"
#include "..\..\lib\rom_tools.h"

/***********************************************
 * NORMAL 32KB
 ***********************************************/
const ROM_ATTR_t ROM_ATTR_NORMAL32 = {
    (uint8_t)(FLAG_WRITE_PROTECT | FLAG_BANK_SIZE), // FLAGS
    (uint8_t)0xFF,                                  // BANK VALUE MASK
    (uint16_t)0x0000,                               // BANK REGISTER ADDRESS MASK
    {
        { (uint16_t)0xFFFF, 0, 0 },                 // BANK #0 REGISTER ADDRESS, INITIAL VALUE, RESERVED
        { (uint16_t)0xFFFF, 0, 0 },                 // BANK #1 REGISTER ADDRESS, INITIAL VALUE, RESERVED
        { (uint16_t)0xFFFF, 0, 0 },                 // BANK #2 REGISTER ADDRESS, INITIAL VALUE, RESERVED
        { (uint16_t)0xFFFF, 0, 0 }                  // BANK #3 REGISTER ADDRESS, INITIAL VALUE, RESERVED
    },
    "NO BANK 32KB"
};

/***********************************************
 * NORMAL 16KB(4000h~7FFFh)
 ***********************************************/
const ROM_ATTR_t ROM_ATTR_NORMAL16_P1 = {
    (uint8_t)(FLAG_WRITE_PROTECT | FLAG_BANK_SIZE | FLAG_CS2_MASK), // FLAGS
    (uint8_t)0xFF,                                  // BANK VALUE MASK
    (uint16_t)0x0000,                               // BANK REGISTER ADDRESS MASK
    {
        { (uint16_t)0xFFFF, 0, 0 },                 // BANK #0 REGISTER ADDRESS, INITIAL VALUE, RESERVED
        { (uint16_t)0xFFFF, 0, 0 },                 // BANK #1 REGISTER ADDRESS, INITIAL VALUE, RESERVED
        { (uint16_t)0xFFFF, 0, 0 },                 // BANK #2 REGISTER ADDRESS, INITIAL VALUE, RESERVED
        { (uint16_t)0xFFFF, 0, 0 }                  // BANK #3 REGISTER ADDRESS, INITIAL VALUE, RESERVED
    },
    "NO BANK 16KB(4000h~)"
};

/***********************************************
 * NORMAL 16KB(8000h~BFFFh)
 ***********************************************/
const ROM_ATTR_t ROM_ATTR_NORMAL16_P2 = {
    (uint8_t)(FLAG_WRITE_PROTECT | FLAG_BANK_SIZE | FLAG_CS1_MASK), // FLAGS
    (uint8_t)0xFF,                                  // BANK VALUE MASK
    (uint16_t)0x0000,                               // BANK REGISTER ADDRESS MASK
    {
        { (uint16_t)0xFFFF, 0, 0 },                 // BANK #0 REGISTER ADDRESS, INITIAL VALUE, RESERVED
        { (uint16_t)0xFFFF, 0, 0 },                 // BANK #1 REGISTER ADDRESS, INITIAL VALUE, RESERVED
        { (uint16_t)0xFFFF, 0, 0 },                 // BANK #2 REGISTER ADDRESS, INITIAL VALUE, RESERVED
        { (uint16_t)0xFFFF, 0, 0 }                  // BANK #3 REGISTER ADDRESS, INITIAL VALUE, RESERVED
    },
    "NO BANK 16KB(8000h~)"
};

/***********************************************
 * ASCII 16KB
 ***********************************************/
const ROM_ATTR_t ROM_ATTR_ASCII16 = {
    (uint8_t)(FLAG_WRITE_PROTECT | FLAG_BANK_SIZE), // FLAGS
    (uint8_t)0xFF,                                  // BANK VALUE MASK
    (uint16_t)0xF800,                               // BANK REGISTER ADDRESS MASK
    {
        { (uint16_t)0x6000, 0, 0 },                 // BANK #0 REGISTER ADDRESS, INITIAL VALUE, RESERVED
        { (uint16_t)0x7000, 0, 0 },                 // BANK #1 REGISTER ADDRESS, INITIAL VALUE, RESERVED
        { (uint16_t)0xFFFF, 0, 0 },                 // BANK #2 REGISTER ADDRESS, INITIAL VALUE, RESERVED
        { (uint16_t)0xFFFF, 0, 0 }                  // BANK #3 REGISTER ADDRESS, INITIAL VALUE, RESERVED
    },
    "ASCII 16KB"
};

/***********************************************
 * ASCII 8KB
 ***********************************************/
const ROM_ATTR_t ROM_ATTR_ASCII8 = {
    (uint8_t)(FLAG_WRITE_PROTECT),                  // FLAGS
    (uint8_t)0xFF,                                  // BANK VALUE MASK
    (uint16_t)0xF800,                               // BANK REGISTER ADDRESS MASK
    {
        { (uint16_t)0x6000, 0, 0 },                 // BANK #0 REGISTER ADDRESS, INITIAL VALUE, RESERVED
        { (uint16_t)0x6800, 0, 0 },                 // BANK #1 REGISTER ADDRESS, INITIAL VALUE, RESERVED
        { (uint16_t)0x7000, 0, 0 },                 // BANK #2 REGISTER ADDRESS, INITIAL VALUE, RESERVED
        { (uint16_t)0x7800, 0, 0 }                  // BANK #3 REGISTER ADDRESS, INITIAL VALUE, RESERVED
    },
    "ASCII 8KB"
};

/***********************************************
 * KONAMI 8KB with SCC sound
 ***********************************************/
const ROM_ATTR_t ROM_ATTR_KONAMI = {
    (uint8_t)(FLAG_WRITE_PROTECT | FLAG_SCC),       // FLAGS
    (uint8_t)0x3F,                                  // BANK VALUE MASK
    (uint16_t)0xF800,                               // BANK REGISTER ADDRESS MASK
    {
        { (uint16_t)0x5000, 0, 0 },                 // BANK #0 REGISTER ADDRESS, INITIAL VALUE, RESERVED
        { (uint16_t)0x7000, 1, 0 },                 // BANK #1 REGISTER ADDRESS, INITIAL VALUE, RESERVED
        { (uint16_t)0x9000, 2, 0 },                 // BANK #2 REGISTER ADDRESS, INITIAL VALUE, RESERVED
        { (uint16_t)0xB000, 3, 0 }                  // BANK #3 REGISTER ADDRESS, INITIAL VALUE, RESERVED
    },
    "KONAMI 8KB with SCC sound"                     // NAME
};

/***********************************************
 * TABLE
 ***********************************************/
const KEYWORD_PARAM_t    rom_attr_table[] = {
    {   "32K",      (void*)&ROM_ATTR_NORMAL32   },
    {   "16K",      (void*)&ROM_ATTR_NORMAL16_P1},
    {   "16K2",     (void*)&ROM_ATTR_NORMAL16_P2},
    {   "ASCII16",  (void*)&ROM_ATTR_ASCII16    },
    {   "ASCII8",   (void*)&ROM_ATTR_ASCII8     },
    {   "KONAMI",   (void*)&ROM_ATTR_KONAMI     },
    {   NULL,       NULL                        }
};
