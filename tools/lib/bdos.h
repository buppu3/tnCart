//
// bdos.h
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

#ifndef _INCLUDE_BDOS_H_
#define _INCLUDE_BDOS_H_

#include "types.h"

#define BDOS_ERR_ABORT      (0x9D)

#define BDOS_OPEN_RW        (0x00)
#define BDOS_OPEN_WRONLY    (0x02)
#define BDOS_OPEN_RDONLY    (0x01)

#define BDOS_ATTR_RDONLY    (0x01)
#define BDOS_ATTR_HIDDEN    (0x02)
#define BDOS_ATTR_SYSTEM    (0x04)
#define BDOS_ATTR_VOLUME    (0x08)
#define BDOS_ATTR_DIRECTORY (0x10)
#define BDOS_ATTR_ARCHIVE   (0x20)
#define BDOS_ATTR_RESERVED  (0x40)
#define BDOS_ATTR_DEVICE    (0x80)
#define BDOS_ATTR_ALL       (0xFF)

typedef struct {
    uint8_t     drive;              //  0
    uint8_t     file_name[8];       //  1~ 8
    uint8_t     file_ext[3];        //  9~11
    uint8_t     current_block;      // 12
    uint8_t     reserved_13;        // 13
    uint8_t     record_size;        // 14
    uint8_t     reserved_15;        // 15
    uint32_t    file_size;          // 16~19
    uint16_t    date;               // 20~21
    uint16_t    time;               // 22~23
    uint8_t     device_id;          // 24
    uint8_t     directory_location; // 25
    uint16_t    start_cluster;      // 26~27
    uint16_t    end_cluster;        // 28~29
    uint16_t    offset_cluster;     // 30~31
    uint8_t     reserved_32;        // 32
    uint32_t    random_record;      // 33~36
} BDOS_FCB_t;

typedef struct {
    uint8_t     handle;
    uint32_t    file_size;
    uint32_t    current_pos;
    uint8_t     buffer[64];
} BDOS_HANDLE_t;

#define TYPE_DOS1       (0)
#define TYPE_DOS2       (1)

typedef struct {
    uint8_t     type;
    uint32_t    current_pos;
    union {
        BDOS_FCB_t      dos1;
        BDOS_HANDLE_t   dos2;
    };
    uint8_t     buffer[128];
} BDOS_FILE_t;

int bdos_fopen(BDOS_FILE_t *file, char *path);
int bdos_fcreate(BDOS_FILE_t *file, char *path);
int bdos_fclose(BDOS_FILE_t *file);
int bdos_file_size(BDOS_FILE_t *file, uint32_t *size);
int bdos_eof(BDOS_FILE_t *file);
int bdos_fread(BDOS_FILE_t *file, uint16_t *readed);
int bdos_fread_n(BDOS_FILE_t *file, uint16_t addr, uint16_t size, uint16_t *readed);
int bdos_fwrite(BDOS_FILE_t *file, uint16_t *written);
int bdos_set_about_handler(uint16_t addr);
int bdos_term(uint8_t code);

#endif
