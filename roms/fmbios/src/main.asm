;
; main.asm
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

; zcc +z80 -startup=-1 -o..\bin\fmbios.rom main.asm driver.asm -create-app -Cz"--rombase=0x4000 --romsize=0x4000"

        DEFC    RDSLT = 000Ch
        DEFC    CALSLT = 001Ch
        DEFC    RSLREG = 0138h
        DEFC    EXPTBL = 0FCC1h
        DEFC    SLTTBL = 0FCC5h
        DEFC    SLTWRK = 0FD09h

        SECTION CODE

        EXTERN  DRV_INIT
        EXTERN  DRV_START
        EXTERN  DRV_STOP
        EXTERN  DRV_CHECK
        EXTERN  DRV_HANDLER

;==============================
; WRITE OPLL REGISTER
;   IN  A = REG#
;       E = DATA
;   OUT none
;==============================
        PUBLIC  WRTOPL
WRTOPL:
        OUT     (7Ch), A
        PUSH    AF
        LD      A,E
        OUT     (7Dh), A
        LD      A, (7FF6h)
        LD      A, (7FF6h)
        LD      A, (7FF6h)
        LD      A, R
        POP     AF
        RET

        LD      (7FF4h),A
        ; 3.36usec(12.03clk)
        PUSH    AF              ; 12
        LD      A,E             ;  5
        LD      (7FF5h),A
        ; 23.52u(84.20clk)
        LD      A, (7FF6h)      ; 14
        LD      A, (7FF6h)      ; 14
        LD      A, (7FF6h)      ; 14
        LD      A, R            ; 10
        POP     AF              ; 11
        RET                     ; 11
                                ; 11

;==============================
; READ DATA
;   IN  HL = DST ADDR
;       A = SOUND#
;   OUT none
;   USE F
;==============================
        PUBLIC  RDDATA
RDDATA:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        PUSH    HL

        ; HL = A * 8
        LD      L, A
        LD      H, 0
        ADD     HL, HL
        ADD     HL, HL
        ADD     HL, HL

        ; HL += 0x4C00
        LD      DE, 4C00h
        ADD     HL, DE

        ; DE = dst address
        POP     DE

        ; BC = 8
        LD      BC, 8

        ; memcpy(DE, HL, BC)
        LDIR

        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

;==============================
; INTIALIZE OPLL
;   IN  HL = WORK AREA ADDRESS
;   OUT none
;   USE AF,BC,DE,HL,IX,IY
;==============================
        PUBLIC  INIOPL
INIOPL:
        ; ワークアドレス保存
        PUSH    HL
        CALL    SETWRK

        ; IX = (WORK_t*)HL
        POP     IX

        ; 内蔵 FM 音源を探す
        CALL    SEARCH_APRLOPLL
        JP      C, SKIP_ENABLE_IO

        ; 内蔵 FM 音源が無いなら自分の I/O ポートを有効にする
        LD      A, (7FF6h)
        OR      1
        LD      (7FF6h), A
SKIP_ENABLE_IO:

        JP      DRV_INIT

;==============================
; START MUSIC
;   IN  HL = DATA ADDRESS
;       A = FLAG
;   OUT none
;   USE AF,BC,DE,HL,IX,IY
;==============================
        PUBLIC  MSTART
MSTART:
        PUSH    AF
        PUSH    HL
        CALL    GETWRK
        POP     HL
        POP     AF
        JP      DRV_START

;==============================
; STOP MUSIC
;   IN  none
;   OUT none
;   USE AF,BC,DE,HL,IX,IY
;==============================
        PUBLIC  MSTOP
MSTOP:
        CALL    GETWRK
        JP      DRV_STOP

;==============================
; BGM END CHECK
;   IN  none
;   OUT A = STATE
;   USE none
;==============================
        PUBLIC  TSTBGM
TSTBGM:
        PUSH    DE
        PUSH    HL
        PUSH    IX
        PUSH    AF
        CALL    GETWRK
        POP     AF
        CALL    DRV_CHECK
        POP     IX
        POP     HL
        POP     DE
        RET

;==============================
; OPLL MUSIC DRIVER INTERRUPT HANDLER
;   IN  none
;   OUT none
;   USE none
;==============================
        PUBLIC  OPLDRV
OPLDRV:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        PUSH    IX
        PUSH    IY
        CALL    GETWRK
        CALL    DRV_HANDLER
        POP     IY
        POP     IX
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

;==============================
; GET SLTWRK ADDR
;   IN  none
;   OUT HL = ADDR
;   USE AF, DE, HL
;==============================
GET_SLTWRK:
        ; 基本スロット番号を取得
        LD      A, (EXPTBL)
        PUSH    AF
        POP     IY                      ; IY = MAIN ROM SLOT
        LD      IX, RSLREG
        CALL    CALSLT

        ; スロットが拡張されているか?
        RRCA
        RRCA
        AND     0b00000011
        LD      E, A                    ; E = ページ1基本スロット番号(0~3)
        LD      D, 0                    ; D = 0
        LD      HL, EXPTBL
        ADD     HL, DE                  ; HL = EXPTBL + ページ1基本スロット番号

        LD      A, (HL)
        AND     0b10000000
        LD      A, 0                    ; A = 0(拡張スロット番号)
        JP      Z, GET_SLTWRK_NOEXP     ; EXPTBL の MSB が 0 ならスキップ

        ; 拡張スロット番号
        LD      HL, SLTTBL
        ADD     HL, DE                  ; HL = SLTTBL + ページ1基本スロット番号
        LD      A, (HL)
        RRCA
        RRCA
        AND     0b00000011              ; A = 拡張スロット番号(0~3)

GET_SLTWRK_NOEXP:
        ; SLTWRK のアドレスを計算
        SLA     E
        SLA     E
        OR      E                       ; A = 基本スロット番号 * 4 + 拡張スロット番号
        ADD     A, A
        ADD     A, A                    ; A = (基本スロット番号 * 4 + 拡張スロット番号) * 4 
        ADD     A, 1                    ; A = (基本スロット番号 * 4 + 拡張スロット番号) * 4 + 1
        ADD     A, A                    ; A = ((基本スロット番号 * 4 + 拡張スロット番号) * 4 + 1) * 2 
        LD      E, A                    ; DE = ((基本スロット番号 * 4 + 拡張スロット番号) * 4 + 1) * 2
        LD      HL, SLTWRK
        ADD     HL, DE                  ; HL = SLTWRK + ((基本スロット番号 * 4 + 拡張スロット番号) * 4 + 1) * 2

        RET

;==============================
; GET WORK ADDR
;   IN  none
;   OUT IX = ADDR
;   USE AF, DE, HL
;==============================
GETWRK:
        CALL    GET_SLTWRK
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        PUSH    DE
        POP     IX
        RET

;==============================
; SET WORK ADDR
;   IN  HL = ADDR
;   OUT none
;   USE AF, DE, HL
;==============================
SETWRK:
        PUSH    HL
        CALL    GET_SLTWRK
        POP     DE
        LD      (HL), E
        INC     HL
        LD      (HL), D
        RET

;==============================
; 内蔵 OPLL があるかチェック
;   IN  none
;   OUT C FLAG = 0:not found
;                1:found other cartridge
;   USE AF, BC
;==============================
SEARCH_APRLOPLL:
        LD      A, 0
SEARCH_APRLOPLL_LOOP:
        BIT     2, A
        JR      NZ, SEARCH_APRLOPLL_EXIT
        CALL    SEARCH_APRLOPLL_PRIMAY
        RET     C
        INC     A
        JR      SEARCH_APRLOPLL_LOOP
SEARCH_APRLOPLL_EXIT:
        XOR     A
        RET

;==============================
; 指定基本スロットに APRLOPLL があるかチェック
;   IN  A = primary slot number
;   OUT C FLAG = 0:not found
;                1:found other cartridge
;   USE F
;==============================
SEARCH_APRLOPLL_PRIMAY:
        PUSH    HL
        PUSH    DE
        PUSH    BC
        PUSH    AF

        ; if(EXPTBL[A] & 0x80) goto SEARCH_APRLOPLL_PRIMAY_EXP;
        LD      E, A
        LD      D, 0
        LD      HL, EXPTBL
        ADD     HL, DE
        LD      A, (HL)
        AND     80h
        JR      NZ, SEARCH_APRLOPLL_PRIMAY_EXP
        LD      A, E

        ; 指定スロットをチェック
        CALL    CHECK_APRLOPLL

        ; 終わり
SEARCH_APRLOPLL_PRIMAY_EXIT:
        POP     BC
        LD      A, B
        POP     BC
        POP     DE
        POP     HL
        RET

SEARCH_APRLOPLL_PRIMAY_EXP:
        ; 拡張スロット番号を作成
        LD      A, 80h
        OR      E

SEARCH_APRLOPLL_PRIMAY_EXP_LOOP:
        ; 指定スロットをチェック
        CALL    CHECK_APRLOPLL
        JP      C, SEARCH_APRLOPLL_PRIMAY_EXIT

        ; 次のセカンダリスロット
        ADD     A, 04h

        ; セカンダリをすべてチェックした?
        BIT     4, A
        JR      NZ, SEARCH_APRLOPLL_PRIMAY_EXP_LOOP

        ; not found
        XOR     A
        JR      SEARCH_APRLOPLL_PRIMAY_EXIT

;==============================
; 指定スロットに APRLOPLL があるかチェック
;   IN  A = slot number
;   OUT C FLAG = 0:not found
;                1:found other cartridge
;   USE F
;==============================
CHECK_APRLOPLL:
        PUSH    HL
        PUSH    DE
        PUSH    BC
        PUSH    AF

        LD      DE, ID_APRLOPLL
        LD      HL, 4018h
        LD      B, 08h

CHECK_APRLOPLL_LOOP:
        CALL    RDSLT
        EX      DE, HL
        CP      (HL)
        EX      DE, HL
        JR      NZ, CHECK_APRLOPLL_NOT_FOUND

        INC     HL
        INC     DE
        POP     AF
        PUSH    AF

        DJNZ    CHECK_APRLOPLL_LOOP

        SCF
        JR      CHECK_APRLOPLL_EXIT

CHECK_APRLOPLL_NOT_FOUND:
        XOR     A

CHECK_APRLOPLL_EXIT:
        POP     BC
        LD      A, B
        POP     BC
        POP     DE
        POP     HL
        RET

ID_APRLOPLL:
        DEFB   'A', 'P', 'R', 'L', 'O', 'P', 'L', 'L'
