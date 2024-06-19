;
; work.inc
;
; BSD 3-Clause License
; 
; Copyright (c) 2024, Shinobu Hashimoto
; 
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
; 
; 1. Redistributions of source code must retain the above copyright notice, this
;    list of conditions and the following disclaimer.
; 
; 2. Redistributions in binary form must reproduce the above copyright notice,
;    this list of conditions and the following disclaimer in the documentation
;    and/or other materials provided with the distribution.
; 
; 3. Neither the name of the copyright holder nor the names of its
;    contributors may be used to endorse or promote products derived from
;    this software without specific prior written permission.
; 
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
; DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
; CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
; OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;

        DEFC    CH_COUNT                = 9     ; チャンネル数

        DEFC    WORK_PLAY_COUNT         = 0     ; 再生CH数
        DEFC    WORK_REPEAT             = 1     ; リピート数
        DEFC    WORK_ADDR_L             = 2     ; 先頭アドレスL
        DEFC    WORK_ADDR_H             = 3     ; 先頭アドレスH
        DEFC    WORK_NOTE_TABLE_L       = 4     ; 音階テーブルL
        DEFC    WORK_NOTE_TABLE_H       = 5     ; 音階テーブルL
        DEFC    WORK_CHWORK             = 6     ; 各 CH ワーク
        DEFC    WORK_SIZE               = WORK_CHWORK + CHWORK_SIZE * CH_COUNT;

        DEFC    CHWORK_NUM              = 0     ; チャンネル番号
        DEFC    CHWORK_FLAGS            = 1     ; フラグ
        DEFC    CHWORK_REG2X            = 2     ; REG2x の値
        DEFC    CHWORK_REG3X            = 3     ; REG3x の値
        DEFC    CHWORK_ADDR_L           = 4     ; 演奏中アドレスL
        DEFC    CHWORK_ADDR_H           = 5     ; 演奏中アドレスH
        DEFC    CHWORK_DELAY_L          = 6     ; 待機カウンタL
        DEFC    CHWORK_DELAY_H          = 7     ; 待機カウンタH
        DEFC    CHWORK_GATE_L           = 8     ; ゲートカウンタL
        DEFC    CHWORK_REG36            = 8     ; BD 音量(REG36)
        DEFC    CHWORK_GATE_H           = 9     ; ゲートカウンタH
        DEFC    CHWORK_REG37            = 9     ; HH_DS 音量(REG37)
        DEFC    CHWORK_Q                = 10    ; Q
        DEFC    CHWORK_REG38            = 10    ; TM_CY 音量(REG38)
        DEFC    CHWORK_SIZE             = 11    ; CH ワークのサイズ

        DEFC    CHWORK_FLAG_SUS         = 5     ; SUS flag
        DEFC    CHWORK_FLAG_LEG         = 4     ; レガート flag
        DEFC    CHWORK_FLAG_RHYTHM      = 1     ; 再生タイプ(0=トーン/1=リズム)
        DEFC    CHWORK_FLAG_PLAY        = 0     ; 再生中フラグ
