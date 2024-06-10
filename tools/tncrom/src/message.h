//
// message.h
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

#ifndef _INCLUDE_MESSAGE_H_
#define _INCLUDE_MESSAGE_H_

#define MSG_VERSION             "ROM loader for tnCart ver %d.%02d\n"\
                                "\n"
#define MSG_USAGE               "USAGE: TNCROM -S [SLOT] -T [TYPE] {-R} {-C} [FILE]\n"
#define MSG_HELP                "OPTION:\n"\
                                "  -H           show help message\n"\
                                "  -R           reboot computer\n"\
                                "  -O           valid until hardware reset\n"\
                                "  -C           use configuration file\n"\
                                "  -S [slot]    set slot number\n"\
                                "  -T [type]    set ROM type\n"
#define MSG_UNKNOWN_ROM_TYPE    "unknown rom type(%s).\n"
#define MSG_CARTRIDGE_NOT_FOUND "cartridge not found.\n"
#define MSG_PROP_SLOT           "SLOT     : %s\n"
#define MSG_PROP_ROM_FILE       "ROM FILE : %s\n"
#define MSG_PROP_ROM_TYPE       "ROM TYPE : %s\n"
#define MSG_HANDLER_ERROR       "can not set handler.\n"
#define MSG_COMPLETE            "complete.\n"
#define MSG_REBOOT              "rebooting...\n"
#define MSG_ERR_FILEREAD        "file read error.\n"
#define MSG_ERR_GETFILESIZE     "can not get file size.\n"
#define MSG_PROGRESS            "\rbank %d"
#define MSG_PROGRESS_TERM       "\r"
#define MSG_ERR_FILEOPEN        "can not open rom image file(%s).\n"

#define MSG_PARAM_MULTI_FILE    "multiple files specified.\n"
#define MSG_PARAM_PATH_TOO_LONG "invalid file name(%s).\n"
#define MSG_PARAM_INVALID_SLOT  "invalid slot format(%s).\n"
#define MSG_PARAM_UNKNOWN       "unknwon option(-%c)\n"

#define MSG_CONF_UNKOWN_KEY     "unknown parameter name %s."
#define MSG_CONF_INVALID_FORMAT "configuration file format error.\n"
#define MSG_CONF_ERR_OPEN       "can not open configuration file(%s).\n"
#define MSG_CONF_ERR_READ       "configuration file reading error.\n"

#endif
