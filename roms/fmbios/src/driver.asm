;
; driver.asm
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

        SECTION CODE

        INCLUDE "work.inc"

        DEFC    DEFAULT_REG3X           = 1Ah
        DEFC    DEFAULT_Q               = 7

        EXTERN  WRTOPL

;==============================
; INTIALIZE OPLL
;   IN  IX = WORK AREA ADDRESS
;   OUT none
;   USE AF,BC,DE,HL,IX,IY
;==============================
        PUBLIC  DRV_INIT
DRV_INIT:
        ; work->PLAY_COUNT = 0;
        XOR     A
        LD      (IX + WORK_PLAY_COUNT), A

        ;
        LD      DE, NOTE_TABLE
        LD      (IX + WORK_NOTE_TABLE_L), E
        LD      (IX + WORK_NOTE_TABLE_H), D

        RET

;==============================
; START MUSIC
;   IN  IX = WORK ADDRESS
;       HL = DATA ADDRESS
;       A = FLAG
;   OUT none
;   USE AF,BC,DE,HL,IX,IY
;   STK 6byte
;==============================
        PUBLIC  DRV_START
DRV_START:
        ; work->ADDR = HL;
        LD      (IX + WORK_ADDR_L), L
        LD      (IX + WORK_ADDR_H), H

        ; work->REPEAT = A;
        LD      (IX + WORK_REPEAT), A

        ; work->PLAY_COUNT = 0;
        XOR     A
        LD      (IX + WORK_PLAY_COUNT), A

        ;
        PUSH    IX
        POP     HL
        LD      DE, WORK_CHWORK
        ADD     HL, DE
        PUSH    HL
        POP     DE
        LD      (DE), A
        INC     DE
        LD      BC, +CHWORK_SIZE * CH_COUNT - 1
        LDIR

        ;
        CALL    REPLAY

        ; return;
        RET

;==============================
; STOP MUSIC
;   IN  IX = WORK ADDRESS
;   OUT none
;   USE AF,BC,DE,HL,IX,IY
;   STK 4byte
;==============================
        PUBLIC  DRV_STOP
DRV_STOP:
        ; work->PLAY_COUNT = 0;
        XOR     A
        LD      (IX + WORK_PLAY_COUNT), A

        ; KEY-OFF
        LD      E, 0
        LD      A, 0x0E
        CALL    WRTOPL
        LD      A, 0x20
        CALL    WRTOPL
        LD      A, 0x21
        CALL    WRTOPL
        LD      A, 0x22
        CALL    WRTOPL
        LD      A, 0x23
        CALL    WRTOPL
        LD      A, 0x24
        CALL    WRTOPL
        LD      A, 0x25
        CALL    WRTOPL
        LD      A, 0x26
        CALL    WRTOPL
        LD      A, 0x27
        CALL    WRTOPL
        LD      A, 0x28
        CALL    WRTOPL
        LD      A, 0x29
        CALL    WRTOPL

        ; return;
        RET

;==============================
; BGM END CHECK
;   IN  IX = WORK ADDRESS
;   OUT A = STATE
;   USE none
;   STK 0byte
;==============================
        PUBLIC  DRV_CHECK
DRV_CHECK:
        LD      A, (IX + WORK_PLAY_COUNT)
        RET

;==============================
; OPLL MUSIC DRIVER INTERRUPT HANDLER
;   IN  IX = WORK ADDRESS
;   OUT none
;   USE AF, BC, DE, HL, IX, IY
;   STK 8byte
;==============================
        PUBLIC  DRV_HANDLER
DRV_HANDLER:
        ; if(work->PLAY_COUNT == 0) return;
        LD      A, (IX + WORK_PLAY_COUNT)
        OR      A
        RET     Z

        ; ch = &work->chwork[0];
        PUSH    IX
        POP     IY
        LD      DE, +WORK_CHWORK
        ADD     IY, DE

        ; cnt = 9;
        LD      B, CH_COUNT

DRV_HANDLER_LOOP:
        PUSH    BC

        ; if(ch->FLAGS & (1<<FLAG_PLAY) == 0) goto skip;
        LD      A, (IY + CHWORK_FLAGS)
        BIT     +CHWORK_FLAG_PLAY, A
        JP      Z, DRV_HANDLER_SKIP

        ; if(ch->FLAGS & (1<<FLAG_RHYTHM) == 0) goto tone;
        AND     1 << CHWORK_FLAG_RHYTHM
        JP      Z, DRV_HANDLER_TONE

        ; RHYTHM_CHANNEL_PROC(ch);
DRV_HANDLER_RHYTHM:
        CALL    RHYTHM_CHANNEL_PROC

        ; goto skip
        JP      DRV_HANDLER_SKIP

        ; TONE_CHANNEL_PROC(ch);
DRV_HANDLER_TONE:
        CALL    TONE_CHANNEL_PROC

DRV_HANDLER_SKIP:
        ; ch++;
        LD      DE, +CHWORK_SIZE
        ADD     IY, DE

        ; if(--cnt != 0) goto DRV_HANDLER_LOOP;
        POP     BC
        DJNZ    DRV_HANDLER_LOOP

        ; if(work->PLAY_COUNT != 0) return;
        LD      A, (IX + WORK_PLAY_COUNT)
        OR      A
        RET     NZ

        ; if(work->REPEAT == 0) goto REPLAY;
        LD      A, (IX + WORK_REPEAT)
        OR      A
        JP      Z, REPLAY

        ; if(--work->REPEAT == 0) return;
        DEC     A
        LD      (IX + WORK_REPEAT), A
        RET     Z

        ; goto REPLAY;
        JP REPLAY

;==============================
; REPLAY
;   IN  IX = WORK ADDRESS
;   OUT none
;   USE AF,BC,DE,HL,IY
;   STK 4byte
;==============================
REPLAY:
        ; ch = &work->chwork[0];
        PUSH    IX
        POP     IY
        LD      DE, +WORK_CHWORK
        ADD     IY, DE

        ; work->PLAY_COUNT = 0;
        XOR     A
        LD      (IX + WORK_PLAY_COUNT), A

        ; DE = work->ADDR;
        LD      E, (IX + WORK_ADDR_L)
        LD      D, (IX + WORK_ADDR_H)

        ; cnt = *DE / 2;
        LD      A, (DE)
        SRA     A
        LD      B, A

        ; flags = 0;
        ; ch_num = 0;
        LD      HL, 0

        ; if(cnt == 9) goto REPLAY_NOT_RHYTHM
        CP      9
        JP      Z, REPLAY_NOT_RHYTHM

        ; flags = 1<<CHWORK_FLAG_RHYTHM;
        ; ch_num = -1;
        LD      HL, 0FF00h | (1<<CHWORK_FLAG_RHYTHM)
REPLAY_NOT_RHYTHM:

        ; play_ch_count = 0;
        LD      C, 0

REPLAY_LOOP:
        ;
        XOR     A
        LD      (IY + CHWORK_DELAY_H), A
        LD      (IY + CHWORK_GATE_L), A
        LD      (IY + CHWORK_GATE_H), A
        LD      (IY + CHWORK_REG2X), A
        LD      (IY + CHWORK_REG38), A
        INC     A
        LD      (IY + CHWORK_DELAY_L), A

        BIT     +CHWORK_FLAG_RHYTHM, L
        JR      NZ, REPLAY_RHYTHM

        LD      A, +DEFAULT_REG3X
        LD      (IY + CHWORK_REG3X), A

        LD      A, +DEFAULT_Q
        LD      (IY + CHWORK_Q), A
REPLAY_RHYTHM:

        ; ch->NUM = ch_num++;
        LD      (IY + CHWORK_NUM), H
        INC     H

        ; ch->FLAGS = flags;
        LD      (IY + CHWORK_FLAGS), L

        ; flags = 0;
        LD      L, 0
        PUSH    HL
        PUSH    BC

        ; BC = (uint16_t*)*DE++;
        LD      A, (DE)
        INC     DE
        LD      C, A
        LD      A, (DE)
        INC     DE
        LD      B, A

        ; if(BC == 0) goto REPLAY_NODATA;
        OR      C
        JP      Z, REPLAY_NODATA

        ; ch->ADDR = work->ADDR + BC;
        LD      L, (IX + WORK_ADDR_L)
        LD      H, (IX + WORK_ADDR_H)
        ADD     HL, BC
        LD      (IY + CHWORK_ADDR_L), L
        LD      (IY + CHWORK_ADDR_H), H

        ; ch->FLAGS |= 1<<CHWORK_FLAG_PLAY;
        LD      A, (IY + CHWORK_FLAGS)
        OR      1 << CHWORK_FLAG_PLAY
        LD      (IY + CHWORK_FLAGS), A

        ; play_ch_count++;
        POP     BC
        INC     C
        PUSH    BC

REPLAY_NODATA:
        ; ch++;
        LD      BC, CHWORK_SIZE
        ADD     IY, BC

        ; if(--cnt != 0) goto REPLAY_LOOP;
        POP     BC
        POP     HL
        DJNZ    REPLAY_LOOP

        ; work->PLAY_COUNT = play_ch_count;
        LD      (IX + WORK_PLAY_COUNT), C

        ; return;
        RET

;==============================
; RHYTHM CHANNEL HANDLER
;   IN  IX = WORK ADDRESS
;       IY = CHANNEL WORK ADDRESS
;   OUT none
;   USE none
;   STK 4byte
;==============================
RHYTHM_CHANNEL_PROC:
;-------------------------------
; DELAY
;-------------------------------
RHYTHM_CHANNEL_PROC_DELAY:
        ; ch->DELAY--;
        LD      C, (IY + CHWORK_DELAY_L)
        LD      B, (IY + CHWORK_DELAY_H)
        DEC     BC
        LD      (IY + CHWORK_DELAY_L), C
        LD      (IY + CHWORK_DELAY_H), B

        ; if(ch->DELAY != 0) return;
        LD      A, B
        OR      C
        RET     NZ

;-------------------------------
; CHECK COMMAND
;-------------------------------
        ; BC = ch->ADDR;
        LD      C, (IY + CHWORK_ADDR_L)
        LD      B, (IY + CHWORK_ADDR_H)

RHYTHM_CHANNEL_PROC_LOOP:
        ; cmd = *BC++;
        LD      A, (BC)
        INC     BC

        ; if((cmd & 0x80) == 0) goto RHYTHM_CHANNEL_PROC_KEYON;
        BIT     7, A
        JP      Z, RHYTHM_CHANNEL_PROC_KEYON

        ; if(cmd == 0xFF) goto TONE_CHANNEL_PROC_TERM;
        CP      0FFh
        JP      Z, TONE_CHANNEL_PROC_TERM

;-------------------------------
; VOLUME
;-------------------------------
RHYTHM_CHANNEL_PROC_VOL:
        ; D = A;
        LD      D, A

        ; A = *BC++ & 0x0F;
        LD      L, A
        LD      A, (BC)
        INC     BC
        AND     0Fh

        ; L = A;
        LD      L, A

        ; H = A << 4;
        RRCA
        RRCA
        RRCA
        RRCA
        AND     0F0h
        LD      H, A

        ; if(D & 0x10) ch->REG36 = (ch_REG36 & 0xF0) | L;
        BIT     4, D
        JP      Z, BD_SKIP
        LD      A, (IY + CHWORK_REG36)
        AND     0F0h
        OR      L
        LD      (IY + CHWORK_REG36), A

        ; WRTOPL(0x36, ch->REG36);
        LD      E, A
        LD      A, 36h
        CALL    WRTOPL
BD_SKIP:

        ; if((D & 0x0C) == 0) goto HH_DS_SKIP;
        LD      A, D
        AND     0Ch
        JP      Z, HH_DS_SKIP

        ; if(D & 0x08) ch->REG37  = (ch->REG37 & 0x0F) | H;
        LD      A, (IY + CHWORK_REG37)
        BIT     3, D
        JP      Z, HH_SKIP
        AND     0Fh
        OR      H
HH_SKIP:

        ; if(D & 0x04) ch->REG37  = (ch->REG37 & 0xF0) | L;
        BIT     2, D
        JP      Z, DS_SKIP
        AND     0F0h
        OR      L
DS_SKIP:
        LD      (IY + CHWORK_REG37), A

        ; WRTOPL(0x37, ch->REG37);
        LD      E, A
        LD      A, 37h
        CALL    WRTOPL
HH_DS_SKIP:

        ; if((D & 0x03) == 0) goto TM_CY_SKIP;
        LD      A, D
        AND     03h
        JP      Z, TM_CY_SKIP

        ; if(D & 0x08) ch->REG38 = (ch->REG38 & 0x0F) | H;
        LD      A, (IY + CHWORK_REG38)
        BIT     1, D
        JP      Z, TM_SKIP
        AND     0Fh
        OR      H
TM_SKIP:

        ; if(D & 0x04) ch->REG38  = (ch->REG38 & 0xF0) | L;
        BIT     0, D
        JP      Z, CY_SKIP
        AND     0F0h
        OR      L
CY_SKIP:
        LD      (IY + CHWORK_REG38), A

        ; WRTOPL(0x38, ch->REG38);
        LD      E, A
        LD      A, 38h
        CALL    WRTOPL
TM_CY_SKIP:

        ; goto RHYTHM_CHANNEL_PROC_LOOP;
        JP      RHYTHM_CHANNEL_PROC_LOOP

;-------------------------------
; KEY ON
;-------------------------------
RHYTHM_CHANNEL_PROC_KEYON:
        ; WRTOPL(0x0E, (cmd & 0x1F) | 0x20);
        AND     1Fh
        OR      20h
        LD      E, A
        LD      A, 0Eh
        CALL    WRTOPL

        ; goto TONE_CHANNEL_PROC_LEN;
        JP      TONE_CHANNEL_PROC_LEN


;==============================
; TONE CHANNEL HANDLER
;   IN  IX = WORK ADDRESS
;       IY = CHANNEL WORK ADDRESS
;   OUT none
;   USE none
;   STK 4bye
;==============================
TONE_CHANNEL_PROC:
;-------------------------------
; GATE
;-------------------------------
TONE_CHANNEL_PROC_GATE:
        ; if(ch->FLAG & 1<<CHWORK_FLAG_LEG) goto TONE_CHANNEL_PROC_GATE_SKIP;
        AND     1 << CHWORK_FLAG_LEG
        JP      NZ, TONE_CHANNEL_PROC_GATE_SKIP

        ; if(ch->GATE == 0) goto TONE_CHANNEL_PROC_GATE_SKIP;
        LD      C, (IY + CHWORK_GATE_L)
        LD      B, (IY + CHWORK_GATE_H)
        LD      A, B
        OR      C
        JP      Z, TONE_CHANNEL_PROC_GATE_SKIP

        ; if(--ch->GATE != 0) goto TONE_CHANNEL_PROC_GATE_SKIP;
        DEC     BC
        LD      (IY + CHWORK_GATE_L), C
        LD      (IY + CHWORK_GATE_H), B
        LD      A, B
        OR      C
        JP      NZ, TONE_CHANNEL_PROC_GATE_SKIP

        ; WRTOPL(ch->NUM + 0x20, ch->REG2X & ~0x10);
        LD      A, (IY + CHWORK_REG2X)
        AND     ~10h
        LD      E, A
        LD      A, (IY + CHWORK_NUM)
        ADD     A, 20h
        CALL    WRTOPL
TONE_CHANNEL_PROC_GATE_SKIP:

;-------------------------------
; DELAY
;-------------------------------
TONE_CHANNEL_PROC_DELAY:
        ; ch->DELAY--;
        LD      C, (IY + CHWORK_DELAY_L)
        LD      B, (IY + CHWORK_DELAY_H)
        DEC     BC
        LD      (IY + CHWORK_DELAY_L), C
        LD      (IY + CHWORK_DELAY_H), B

        ; if(ch->DELAY != 0) return;
        LD      A, B
        OR      C
        RET     NZ

;-------------------------------
; CHECK COMMAND
;-------------------------------
        ; BC = ch->ADDR;
        LD      C, (IY + CHWORK_ADDR_L)
        LD      B, (IY + CHWORK_ADDR_H)

TONE_CHANNEL_PROC_LOOP:
        ; cmd = *BC++;
        LD      A, (BC)
        INC     BC

        ; if(cmd == 0x00) goto TONE_CHANNEL_PROCREST;
        OR      A
        JP      Z, TONE_CHANNEL_PROC_REST               ; 00h

        ; if(cmd < 0x60) goto TONE_CHANNEL_PROC_KEYON;
        CP      60h
        JP      C, TONE_CHANNEL_PROC_KEYON              ; 01h~5Fh

        ; if(cmd < 0x70) goto TONE_CHANNEL_PROC_VOLUME;
        CP      70h
        JP      C, TONE_CHANNEL_PROC_VOLUME             ; 60h~6Fh

        ; if(cmd < 0x80) goto TONE_CHANNEL_PROC_INST;
        CP      80h
        JP      C, TONE_CHANNEL_PROC_INST              ; 70h~7Fh

        ; if(cmd == 0x80) goto TONE_CHANNEL_PROC_SUS_OFF;
        AND     7Fh
        JP      Z, TONE_CHANNEL_PROC_SUS_OFF            ; 80h

        ; if(cmd == 0x81) goto TONE_CHANNEL_PROC_SUS_ON;
        DEC     A
        JP      Z, TONE_CHANNEL_PROC_SUS_ON             ; 81h

        ; if(cmd == 0x82) goto TONE_CHANNEL_PROC_EXT_INST;
        DEC     A
        JP      Z, TONE_CHANNEL_PROC_EXT_INST          ; 82h

        ; if(cmd == 0x83) goto TONE_CHANNEL_PROC_USR_INST;
        DEC     A
        JP      Z, TONE_CHANNEL_PROC_USR_INST          ; 83h

        ; if(cmd == 0x84) goto TONE_CHANNEL_PROC_LEG_OFF;
        DEC     A
        JP      Z, TONE_CHANNEL_PROC_LEG_OFF            ; 84h

        ; if(cmd == 0x85) goto TONE_CHANNEL_PROC_LEG_ON;
        DEC     A
        JP      Z, TONE_CHANNEL_PROC_LEG_ON             ; 85h

        ; if(cmd == 0x86) goto TONE_CHANNEL_PROC_Q;
        DEC     A
        JP      Z, TONE_CHANNEL_PROC_Q                  ; 86h

;-------------------------------
; TERM
;-------------------------------
TONE_CHANNEL_PROC_TERM:
        ; ch->FLAGS &= ~(1 << CHWORK_FLAG_PLAY);
        LD      A, (IY + CHWORK_FLAGS)
        AND     ~(1 << CHWORK_FLAG_PLAY)
        LD      (IY + CHWORK_FLAGS), A

        ; work->PLAY_COUNT--;
        LD      A, (IX + WORK_PLAY_COUNT)
        DEC     A
        LD      (IX + WORK_PLAY_COUNT), A

        ; return;
        RET

;-------------------------------
; KEYON
;-------------------------------
TONE_CHANNEL_PROC_KEYON:
        ; HL = NOTE_TABLE + A * 2;
        LD      L, A
        LD      H, 0
        LD      E, (IX + WORK_NOTE_TABLE_L)
        LD      D, (IX + WORK_NOTE_TABLE_H)
        ADD     HL, HL
        ADD     HL, DE

        ; WRTOPL(ch->NUM + 0x10, *HL++);
        LD      A, (IY + CHWORK_NUM)
        ADD     A, 10h
        LD      E, (HL)
        INC     HL
        CALL    WRTOPL

        ; A = ch->FLAGS | 0x10 | *HL;
        LD      A, (IY + CHWORK_FLAGS)
        AND     1 << CHWORK_FLAG_SUS
        OR      10h
        LD      E, A
        LD      A, (HL)
        OR      E

        ; ch->REG2X = A;
        LD      (IY + CHWORK_REG2X), A

        ; WRTOPL(ch->NUM + 0x20, A);
        LD      E, A
        LD      A, (IY + CHWORK_NUM)
        ADD     A, 20h
        CALL    WRTOPL
TONE_CHANNEL_PROC_REST:

TONE_CHANNEL_PROC_LEN:
        ; HL = 0;
        LD      HL, 0
        LD      D, 0
TONE_CHANNEL_PROC_LEN_LOOP:
        ; A = *BC++;
        LD      A, (BC)
        INC     BC

        ; HL += *BC++;
        LD      E, A
        ADD     HL, DE

        ; if(A == 0xFF) goto TONE_CHANNEL_PROC_LEN_LOOP;
        INC     A
        JP      Z, TONE_CHANNEL_PROC_LEN_LOOP

        ; ch->DELAY = HL;
        LD      (IY + CHWORK_DELAY_L), L
        LD      (IY + CHWORK_DELAY_H), H

        ; if(ch->FLAGS & (1<<CHWORK_FLAG_RHYTHM)) goto TONE_CHANNEL_PROC_LEN_SKIP_GATE;
        LD      A, (IY + CHWORK_FLAGS)
        AND     1 << CHWORK_FLAG_RHYTHM
        JP      NZ, TONE_CHANNEL_PROC_LEN_SKIP_GATE

        ; DE = HL;
        PUSH    HL
        POP     DE

        ; HL = 0;
        LD      HL, 0

        ; if(ch->Q & 1) HL += DE;
        LD      A, (IY + CHWORK_Q)
        BIT     0, A
        JP      Z, TONE_CHANNEL_PROC_LEN_SKIP_GATE_0
        ADD     HL, DE
TONE_CHANNEL_PROC_LEN_SKIP_GATE_0:

        ; DE <<= 1;
        SLA     E
        RL      D

        ; if(ch->Q & 2) HL += DE;
        BIT     1, A
        JP      Z, TONE_CHANNEL_PROC_LEN_SKIP_GATE_1
        ADD     HL, DE
TONE_CHANNEL_PROC_LEN_SKIP_GATE_1:

        ; DE <<= 1;
        SLA     E
        RL      D

        ; if(ch->Q & 4) HL += DE;
        BIT     2, A
        JP      Z, TONE_CHANNEL_PROC_LEN_SKIP_GATE_2
        ADD     HL, DE
TONE_CHANNEL_PROC_LEN_SKIP_GATE_2:

        ; DE <<= 1;
        SLA     E
        RL      D

        ; if(ch->Q & 4) HL += DE;
        BIT     3, A
        JP      Z, TONE_CHANNEL_PROC_LEN_SKIP_GATE_3
        ADD     HL, DE
TONE_CHANNEL_PROC_LEN_SKIP_GATE_3:

        ; HL /= 8;
        SRL     H
        RR      L
        SRL     H
        RR      L
        SRL     H
        RR      L

        ; ch->GATE = HL;
        LD      (IY + CHWORK_GATE_L), L
        LD      (IY + CHWORK_GATE_H), H
TONE_CHANNEL_PROC_LEN_SKIP_GATE:

        ; ch->ADDR = BC;
        LD      (IY + CHWORK_ADDR_L), C
        LD      (IY + CHWORK_ADDR_H), B
        
        ; return;
        RET

;-------------------------------
; VOLUME
;-------------------------------
TONE_CHANNEL_PROC_VOLUME:
        ; ch->REG3X = (ch->REG3X & 0xF0) | (cmd & 0x0F);
        AND     0Fh
        LD      E, A
        LD      A, (IY + CHWORK_REG3X)
        AND     0F0h
        OR      E
        LD      (IY + CHWORK_REG3X), A

        ; WRTOPL(ch->num + 0x30, ch->REG3X);
        LD      E, A
        LD      A, (IY + CHWORK_NUM)
        ADD     A, 30h
        CALL    WRTOPL
        JP      TONE_CHANNEL_PROC_LOOP

;-------------------------------
; INST
;-------------------------------
TONE_CHANNEL_PROC_INST:
        ; ch->REG3X = (ch->REG3X & 0x0F) | ((cmd << 4) 0xF0);
        RLCA
        RLCA
        RLCA
        RLCA
        AND     0F0h
        LD      E, A
        LD      A, (IY + CHWORK_REG3X)
        AND     0Fh
        OR      E
        LD      (IY + CHWORK_REG3X), A

        ; WRTOPL(ch->num + 0x30, ch->REG3X);
        LD      E, A
        LD      A, (IY + CHWORK_NUM)
        ADD     A, 30h
        CALL    WRTOPL
        JP      TONE_CHANNEL_PROC_LOOP

;-------------------------------
; SUS OFF
;-------------------------------
TONE_CHANNEL_PROC_SUS_OFF:
        ; ch->FLAGS &= ~(1<<CHWORK_FLAG_SUS);
        LD      A, (IY + CHWORK_FLAGS)
        AND     ~(1 << CHWORK_FLAG_SUS)
        LD      (IY + CHWORK_FLAGS), A

        ; goto TONE_CHANNEL_PROC_LOOP;
        JP      TONE_CHANNEL_PROC_LOOP

;-------------------------------
; SUS OFF
;-------------------------------
TONE_CHANNEL_PROC_SUS_ON:
        ; ch->FLAGS |= (1<<CHWORK_FLAG_SUS);
        LD      A, (IY + CHWORK_FLAGS)
        OR      1 << CHWORK_FLAG_SUS
        LD      (IY + CHWORK_FLAGS), A

        ; goto TONE_CHANNEL_PROC_LOOP;
        JP      TONE_CHANNEL_PROC_LOOP

;-------------------------------
; EXT INST
;-------------------------------
TONE_CHANNEL_PROC_EXT_INST:
        ; A = *BC++ & 0x3F;
        LD      A, (BC)
        INC     BC
        AND     3Fh

        ; HL = 0x4C00 + A * 8
        LD      L, A
        LD      H, 0
        ADD     HL, HL
        ADD     HL, HL
        ADD     HL, HL
        LD      DE, 4C00h
        ADD     HL, DE

        ; GOTO TONE_CHANNEL_PTR_INST;
        JP      TONE_CHANNEL_PTR_INST

;-------------------------------
; USR INST
;-------------------------------
TONE_CHANNEL_PROC_USR_INST:
        ; L = *BC++;
        LD      A, (BC)
        LD      L, A
        INC     BC

        ;H = *BC++;
        LD      A, (BC)
        LD      H, A
        INC     BC

TONE_CHANNEL_PTR_INST:
        PUSH    BC

        ; cnt = 9;
        LD      B, 8

        ; reg = 0;
        LD      A, 0

TONE_CHANNEL_PTR_INST_LOOP:
        ; WRTOPL(reg++, *HL++);
        LD      E, (HL)
        INC     HL
        CALL    WRTOPL
        INC     A

        ; if(--cnt != 0) goto TONE_CHANNEL_PTR_INST_LOOP;
        DJNZ    TONE_CHANNEL_PTR_INST_LOOP

        ; goto TONE_CHANNEL_PROC_LOOP;
        POP     BC
        JP      TONE_CHANNEL_PROC_LOOP

;-------------------------------
; LEG OFF
;-------------------------------
TONE_CHANNEL_PROC_LEG_OFF:
        ; ch->FLAGS &= ~(1<<CHWORK_FLAG_LEG);
        LD      A, (IY + CHWORK_FLAGS)
        AND     ~(1 << CHWORK_FLAG_LEG)
        LD      (IY + CHWORK_FLAGS), A

        ; goto TONE_CHANNEL_PROC_LOOP;
        JP      TONE_CHANNEL_PROC_LOOP

;-------------------------------
; LEG OFF
;-------------------------------
TONE_CHANNEL_PROC_LEG_ON:
        ; ch->FLAGS |= (1<<CHWORK_FLAG_LEG);
        LD      A, (IY + CHWORK_FLAGS)
        OR      1 << CHWORK_FLAG_LEG
        LD      (IY + CHWORK_FLAGS), A

        ; goto TONE_CHANNEL_PROC_LOOP;
        JP      TONE_CHANNEL_PROC_LOOP

;-------------------------------
; Q
;-------------------------------
TONE_CHANNEL_PROC_Q:
        ; ch->Q = *BC++;
        LD      A, (BC)
        INC     BC
        LD      (IY + CHWORK_Q), A

        ; goto TONE_CHANNEL_PROC_LOOP;
        JP      TONE_CHANNEL_PROC_LOOP

;==============================
; NOTE TABLE
;==============================
;#define MAKE_NOTE_VALUE(B,F) (((F) >> (7-(B)) * 262144 * 72) / (3579545 << (B)))
#define MAKE_NOTE_VALUE(B,F) ((((((F) >> (7-(B))) * 58) >> B) / 11) & 1FFh) | (B << 9)

NOTE_TABLE:
        INCLUDE "note_table_equal.inc"
