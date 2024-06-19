;
; debug.asm
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

; zcc +z80 -startup=-1 -o..\bin\fmbios.rom main.asm driver.asm debug.asm -Ca-DENABLE_DEBUG -create-app -Cz"--rombase=0x4000 --romsize=0x4000"

        INCLUDE "work.inc"

        DEFC    _WRTOPL = 4110h
        DEFC    _INIOPL = 4113h
        DEFC    _MSTART = 4116h
        DEFC    _MSTOP  = 4119h
        DEFC    _RDDATA = 411Ch
        DEFC    _OPLDRV = 411Fh
        DEFC    _TSTBGM = 4122h

        DEFC    RSLREG = 0138h
        DEFC    CHPUT = 00A2h
        DEFC    H_TIMI = 0FD9Fh
        DEFC    EXPTBL = 0FCC1h
        DEFC    SLTTBL = 0FCC5h

        DEFC    WORK_HANDER = 0C000h
        DEFC    WORK_OPLDRV = 0C010h

        SECTION CODE
        PUBLIC  TEST
TEST:
        LD      HL, MSG_INIT
        CALL    PUTSTR

        ; INIOPL をコール
        LD      HL, WORK_OPLDRV
        CALL    _INIOPL

        LD      HL, MSG_SETTIMI
        CALL    PUTSTR

        ; 自分のスロット番号を得る
        CALL    GET_MY_SLOT

        ; 割り込み禁止
        DI

        ; ハンドラを RAM にコピー
        LD      HL, TIMI_HANDLER
        LD      DE, WORK_HANDER
        LD      BC, 11
        LDIR

        ; SLOT number
        LD      (WORK_HANDER + (TIMI_HANDLER_SLOT - TIMI_HANDLER)), A

        ; ハンドラに旧フックをコピー
        LD      HL, H_TIMI
        LD      DE, WORK_HANDER + (TIMI_HANDLER_OLD_HOOK - TIMI_HANDLER)
        LD      BC, 5
        LDIR

        ; 新しいフックを書く
        LD      HL, TIMI_HOOK
        LD      DE, H_TIMI
        LD      BC, 5
        LDIR

        ; 割り込み許可
        EI

        LD      HL, MSG_START
        CALL    PUTSTR

        ; MSTART をコール
        LD      A, 0
        LD      HL, TEST_DATA
        CALL    _MSTART

        LD      HL, MSG_DONE
        CALL    PUTSTR

loop:   LD      IX, WORK_OPLDRV + WORK_CHWORK + CHWORK_SIZE * 0
        CALL    PUT_CURR_ADDR
        LD      A,13
        CALL    CHPUT
        JP      loop

;---------------------------
; 再生中アドレス表示
;---------------------------
PUT_CURR_ADDR:
        DI
        LD      L, (IX + CHWORK_ADDR_L)
        LD      H, (IX + CHWORK_ADDR_H)
        EI
        PUSH    HL
        LD      A, H
        CALL    PUTHEX8
        POP     HL
        LD      A, L
        CALL    PUTHEX8
        RET

;---------------------------
; 8ビット hex 表示
;---------------------------
PUTHEX8:
        PUSH    AF
        RRCA
        RRCA
        RRCA
        RRCA
        AND     0Fh
        CALL    PUTHEX4
        POP     AF
        AND     0Fh
        JP      PUTHEX4

;---------------------------
; 4ビット hex 表示
;---------------------------
PUTHEX4:
        CP      10
        JR      C, PUTHEX4_num
        ADD     A, 'A' - 10
        JP      CHPUT
PUTHEX4_num:
        ADD     A, '0'
        JP      CHPUT

;---------------------------
; 文字列表示
;---------------------------
PUTSTR:
PUTSTR_LOOP:
        LD      A, (HL)
        OR      A
        RET     Z
        PUSH    HL
        CALL    CHPUT
        POP     HL
        INC     HL
        JR      PUTSTR_LOOP

;---------------------------
; 自分のスロット番号を取得
;---------------------------
GET_MY_SLOT:
        ; DE = primary_slot;
        CALL    RSLREG
        RRCA
        RRCA
        AND     03h
        LD      E, A
        LD      D, 0

        ; check EXPTBL
        LD      HL, EXPTBL
        ADD     HL, DE
        LD      A, (HL)
        AND     80h
        JR      Z, no_exp

        ; A = 0x80 | ((secondary_slot) << 2);
        LD      HL, SLTTBL
        ADD     HL, DE
        LD      A, (HL)
        AND     0Ch
        OR      80h
no_exp:
        ; A |= primary_slot;
        OR      E
        RET

;---------------------------
; H.TIMI フック内容
;---------------------------
TIMI_HOOK:
        JP      0C000h
        NOP
        NOP

;---------------------------
; TIMI 割り込みハンドラ
;---------------------------
TIMI_HANDLER:
        RST     30h                     ; C000h
TIMI_HANDLER_SLOT:
        DEFB    80h | (1 << 2) | 2      ; C001h
        DEFW    _OPLDRV                 ; C002h, C003h
TIMI_HANDLER_OLD_HOOK:
        DEFB    00h                     ; C004h
        DEFB    00h
        DEFB    00h
        DEFB    00h
        DEFB    00h
        RET

MSG_INIT:
        DEFB    "INIOPL\r\n", 0

MSG_SETTIMI:
        DEFB    "SET H.TIMI\r\n", 0

MSG_START:
        DEFB    "MSTART\r\n", 0

MSG_DONE:
        DEFB    "DONE\r\n", 0

TEST_DATA:
        INCLUDE "testdata.inc"
