//
// config.c
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
#include <stddef.h>
#include "..\..\lib\bdos.h"
#include "..\..\lib\tools.h"
#include "config.h"
#include "message.h"

typedef struct {
    char    *keyword;
    char    *buffer;
    int     buffer_size;
} CONFIG_FORMAT_t;

static BDOS_FILE_t conf_file;
CONFIG_t config;

static const CONFIG_FORMAT_t config_fmt[] = {
    {   "FILE",     config.rom_file,    sizeof(config.rom_file) },
    {   "TYPE",     config.rom_type,    sizeof(config.rom_type) },
    {   NULL,       NULL,               0                       }
};


static enum {
    STATE_NAME_BEGIN,
    STATE_NAME_SKIP_PRE_SPACE,
    STATE_NAME_GET,
    STATE_NAME_SKIP_POST_SPACE,
    STATE_NAME_COMPLETE,
    STATE_VALUE_SKIP_PRE_SPACE,
    STATE_VALUE_GET,
    STATE_VALUE_SKIP_POST_SPACE,
    STATE_COMPLETE,
    STATE_COMMENT
} state;

static char name[8];
static int name_len;
static int value_len;
static const CONFIG_FORMAT_t *item;

static int config_process(char ch)
{
    //
    // コメント
    //
    if(state == STATE_COMMENT)
    {
        if(ch == 13)
        {
            state = STATE_NAME_BEGIN;
        }
        return 0;
    }

    //
    // キー名を取得
    //
    if(state == STATE_NAME_BEGIN)
    {
        state = STATE_NAME_SKIP_PRE_SPACE;
        name_len = 0;
        name[0] = '\0';
    }

    if(state == STATE_NAME_SKIP_PRE_SPACE)
    {
        if(ch == 13)
        {
            state = STATE_NAME_BEGIN;
            return 0;
        }
        else if(ch == ';')
        {
            state = STATE_COMMENT;
            return 0;
        }
        else if(ch > 32)
        {
            state = STATE_NAME_GET;
        }
    }

    if(state == STATE_NAME_GET)
    {
        if(ch == 13)
        {
            goto err;
        }
        else if(ch <= 32)
        {
            state = STATE_NAME_SKIP_POST_SPACE;
        }
        else if(ch == '=')
        {
            state = STATE_NAME_COMPLETE;
            return 0;
        }
        else
        {
            if(name_len < sizeof(name)){
                name[name_len++] = ch;
                name[name_len] = '\0';
            }
            return 0;
        }
    }

    if(state == STATE_NAME_SKIP_POST_SPACE)
    {
        if(ch == 13)
        {
            goto err;
        }
        else if(ch == '=')
        {
            state = STATE_NAME_COMPLETE;
            return 0;
        }
        else if(ch > 32)
        {
            goto err;
        }
    }

    //
    // キー名取得完了
    //
    if(state == STATE_NAME_COMPLETE)
    {
        value_len = 0;
        state = STATE_VALUE_SKIP_PRE_SPACE;

        // キー名からパラメータを探す
        item = config_fmt;
        while(item->keyword != NULL)
        {
            if(strcmpi(item->keyword, name) == 0) break;
            item++;
        }
        if(item->keyword == NULL)
        {
            printf(MSG_CONF_UNKOWN_KEY, name);
            return -1;
        }

        item->buffer[0] = '\0';
    }

    //
    // 値を取得
    //
    if(state == STATE_VALUE_SKIP_PRE_SPACE)
    {
        if(ch == 13)
        {
            state = STATE_COMPLETE;
        }
        else if(ch <= 32)
        {
            return 0;
        }
        else
        {
            state = STATE_VALUE_GET;
        }
    }

    if(state == STATE_VALUE_GET)
    {
        if(ch == 13)
        {
            state = STATE_COMPLETE;
        }
        else if(ch <= 32)
        {
            state = STATE_VALUE_SKIP_POST_SPACE;
        }
        else
        {
            if(value_len < item->buffer_size)
            {
                item->buffer[value_len++] = ch;
                item->buffer[value_len] = '\0';
            }
        }
    }

    if(state == STATE_VALUE_SKIP_POST_SPACE)
    {
        if(ch == 13)
        {
            state = STATE_COMPLETE;
        }
        else if(ch > 32){
            goto err;
        }
        else
        {
            return 0;
        }
    }

    if(state == STATE_COMPLETE)
    {
        state = STATE_NAME_BEGIN;
    }

    return 0;   

err:
    printf(MSG_CONF_INVALID_FORMAT);
    return -1;

}

int load_config_file(char *config_path)
{
    int res;

    memset(&config, 0, sizeof(CONFIG_t));

    if(0 != (res = bdos_fopen(&conf_file, config_path)))
    {
        printf(MSG_CONF_ERR_OPEN, config_path);
        return res;
    }

    while(!bdos_eof(&conf_file))
    {
        uint16_t readed;
        if(0 != (res = bdos_fread(&conf_file, &readed)))
        {
            bdos_fclose(&conf_file);
            printf(MSG_CONF_ERR_READ);
            return res;
        }

        char *p = conf_file.buffer;
        while(readed-- > 0)
        {
            if(config_process(*p++)){
                bdos_fclose(&conf_file);
                return -1;
            }
        }
    }

    bdos_fclose(&conf_file);

    return 0;
}
