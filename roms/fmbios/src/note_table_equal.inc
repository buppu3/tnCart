;
; note_table_equal.asm
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

    DEFC    NOTE_EQU_C      = 4186
    DEFC    NOTE_EQU_CS     = 4435
    DEFC    NOTE_EQU_D      = 4699
    DEFC    NOTE_EQU_DS     = 4978
    DEFC    NOTE_EQU_E      = 5274
    DEFC    NOTE_EQU_F      = 5588
    DEFC    NOTE_EQU_FS     = 5920
    DEFC    NOTE_EQU_G      = 6272
    DEFC    NOTE_EQU_GS     = 6645
    DEFC    NOTE_EQU_A      = 7040
    DEFC    NOTE_EQU_AS     = 7459
    DEFC    NOTE_EQU_B      = 7902

    DEFW    0                                   ; 00h REST
    DEFW    MAKE_NOTE_VALUE(0, NOTE_EQU_C)      ; 01h C1
    DEFW    MAKE_NOTE_VALUE(0, NOTE_EQU_CS)     ; 02h C+1
    DEFW    MAKE_NOTE_VALUE(0, NOTE_EQU_D)      ; 03h D1
    DEFW    MAKE_NOTE_VALUE(0, NOTE_EQU_DS)     ; 04h D+1
    DEFW    MAKE_NOTE_VALUE(0, NOTE_EQU_E)      ; 05h E1
    DEFW    MAKE_NOTE_VALUE(0, NOTE_EQU_F)      ; 06h F1
    DEFW    MAKE_NOTE_VALUE(0, NOTE_EQU_FS)     ; 07h F+1
    DEFW    MAKE_NOTE_VALUE(0, NOTE_EQU_G)      ; 08h G1
    DEFW    MAKE_NOTE_VALUE(0, NOTE_EQU_GS)     ; 09h G+1
    DEFW    MAKE_NOTE_VALUE(0, NOTE_EQU_A)      ; 0Ah A
    DEFW    MAKE_NOTE_VALUE(0, NOTE_EQU_AS)     ; 0Bh A+1     55.000
    DEFW    MAKE_NOTE_VALUE(0, NOTE_EQU_B)      ; 0Ch B1
    DEFW    MAKE_NOTE_VALUE(1, NOTE_EQU_C)      ; 0Dh C2
    DEFW    MAKE_NOTE_VALUE(1, NOTE_EQU_CS)     ; 0Eh C+2
    DEFW    MAKE_NOTE_VALUE(1, NOTE_EQU_D)      ; 0F0 D2

    DEFW    MAKE_NOTE_VALUE(1, NOTE_EQU_DS)     ; 10h D+2
    DEFW    MAKE_NOTE_VALUE(1, NOTE_EQU_E)      ; 11h E2
    DEFW    MAKE_NOTE_VALUE(1, NOTE_EQU_F)      ; 12h F2
    DEFW    MAKE_NOTE_VALUE(1, NOTE_EQU_FS)     ; 13h F+2
    DEFW    MAKE_NOTE_VALUE(1, NOTE_EQU_G)      ; 14h G2
    DEFW    MAKE_NOTE_VALUE(1, NOTE_EQU_GS)     ; 15h G+2
    DEFW    MAKE_NOTE_VALUE(1, NOTE_EQU_A)      ; 16h A2     110.000
    DEFW    MAKE_NOTE_VALUE(1, NOTE_EQU_AS)     ; 17h A+2
    DEFW    MAKE_NOTE_VALUE(1, NOTE_EQU_B)      ; 18h B2
    DEFW    MAKE_NOTE_VALUE(2, NOTE_EQU_C)      ; 19h C3
    DEFW    MAKE_NOTE_VALUE(2, NOTE_EQU_CS)     ; 1Ah C+3
    DEFW    MAKE_NOTE_VALUE(2, NOTE_EQU_D)      ; 1Bh D3
    DEFW    MAKE_NOTE_VALUE(2, NOTE_EQU_DS)     ; 1Ch D+3
    DEFW    MAKE_NOTE_VALUE(2, NOTE_EQU_E)      ; 1Dh E3
    DEFW    MAKE_NOTE_VALUE(2, NOTE_EQU_F)      ; 1Eh F3
    DEFW    MAKE_NOTE_VALUE(2, NOTE_EQU_FS)     ; 1Fh F+3

    DEFW    MAKE_NOTE_VALUE(2, NOTE_EQU_G)      ; 20h G3
    DEFW    MAKE_NOTE_VALUE(2, NOTE_EQU_GS)     ; 21h G+3
    DEFW    MAKE_NOTE_VALUE(2, NOTE_EQU_A)      ; 22h A3     220.000
    DEFW    MAKE_NOTE_VALUE(2, NOTE_EQU_AS)     ; 23h A+3
    DEFW    MAKE_NOTE_VALUE(2, NOTE_EQU_B)      ; 24h B3
    DEFW    MAKE_NOTE_VALUE(3, NOTE_EQU_C)      ; 25h C4
    DEFW    MAKE_NOTE_VALUE(3, NOTE_EQU_CS)     ; 26h C+4
    DEFW    MAKE_NOTE_VALUE(3, NOTE_EQU_D)      ; 27h D4
    DEFW    MAKE_NOTE_VALUE(3, NOTE_EQU_DS)     ; 28h D+4
    DEFW    MAKE_NOTE_VALUE(3, NOTE_EQU_E)      ; 29h E4
    DEFW    MAKE_NOTE_VALUE(3, NOTE_EQU_F)      ; 2Ah F4
    DEFW    MAKE_NOTE_VALUE(3, NOTE_EQU_FS)     ; 2Bh F+4
    DEFW    MAKE_NOTE_VALUE(3, NOTE_EQU_G)      ; 2Ch G4
    DEFW    MAKE_NOTE_VALUE(3, NOTE_EQU_GS)     ; 2Dh G+4
    DEFW    MAKE_NOTE_VALUE(3, NOTE_EQU_A)      ; 2Eh A4     440.000
    DEFW    MAKE_NOTE_VALUE(3, NOTE_EQU_AS)     ; 2Fh A+4

    DEFW    MAKE_NOTE_VALUE(3, NOTE_EQU_B)      ; 30h B4
    DEFW    MAKE_NOTE_VALUE(4, NOTE_EQU_C)      ; 31h C5
    DEFW    MAKE_NOTE_VALUE(4, NOTE_EQU_CS)     ; 32h C+5
    DEFW    MAKE_NOTE_VALUE(4, NOTE_EQU_D)      ; 33h D5
    DEFW    MAKE_NOTE_VALUE(4, NOTE_EQU_DS)     ; 34h D+5
    DEFW    MAKE_NOTE_VALUE(4, NOTE_EQU_E)      ; 35h E5
    DEFW    MAKE_NOTE_VALUE(4, NOTE_EQU_F)      ; 36h F5
    DEFW    MAKE_NOTE_VALUE(4, NOTE_EQU_FS)     ; 37h F+5
    DEFW    MAKE_NOTE_VALUE(4, NOTE_EQU_G)      ; 38h G5
    DEFW    MAKE_NOTE_VALUE(4, NOTE_EQU_GS)     ; 39h G+5
    DEFW    MAKE_NOTE_VALUE(4, NOTE_EQU_A)      ; 3Ah A5     880.000
    DEFW    MAKE_NOTE_VALUE(4, NOTE_EQU_AS)     ; 3Bh A+5
    DEFW    MAKE_NOTE_VALUE(4, NOTE_EQU_B)      ; 3Ch B5
    DEFW    MAKE_NOTE_VALUE(5, NOTE_EQU_C)      ; 3Dh C6
    DEFW    MAKE_NOTE_VALUE(5, NOTE_EQU_CS)     ; 3Eh C+6
    DEFW    MAKE_NOTE_VALUE(5, NOTE_EQU_D)      ; 3Fh D6

    DEFW    MAKE_NOTE_VALUE(5, NOTE_EQU_DS)     ; 40h D+6
    DEFW    MAKE_NOTE_VALUE(5, NOTE_EQU_E)      ; 41h E6
    DEFW    MAKE_NOTE_VALUE(5, NOTE_EQU_F)      ; 42h F6
    DEFW    MAKE_NOTE_VALUE(5, NOTE_EQU_FS)     ; 43h F+6
    DEFW    MAKE_NOTE_VALUE(5, NOTE_EQU_G)      ; 44h G6
    DEFW    MAKE_NOTE_VALUE(5, NOTE_EQU_GS)     ; 45h G+6
    DEFW    MAKE_NOTE_VALUE(5, NOTE_EQU_A)      ; 46h A6    1760.000
    DEFW    MAKE_NOTE_VALUE(5, NOTE_EQU_AS)     ; 47h A+6
    DEFW    MAKE_NOTE_VALUE(5, NOTE_EQU_B)      ; 48h B6
    DEFW    MAKE_NOTE_VALUE(6, NOTE_EQU_C)      ; 49h C7
    DEFW    MAKE_NOTE_VALUE(6, NOTE_EQU_CS)     ; 4Ah C+7
    DEFW    MAKE_NOTE_VALUE(6, NOTE_EQU_D)      ; 4Bh D7
    DEFW    MAKE_NOTE_VALUE(6, NOTE_EQU_DS)     ; 4Ch D+7
    DEFW    MAKE_NOTE_VALUE(6, NOTE_EQU_E)      ; 4Dh E7
    DEFW    MAKE_NOTE_VALUE(6, NOTE_EQU_F)      ; 4Eh F7
    DEFW    MAKE_NOTE_VALUE(6, NOTE_EQU_FS)     ; 4Fh F+7

    DEFW    MAKE_NOTE_VALUE(6, NOTE_EQU_G)      ; 50h G7
    DEFW    MAKE_NOTE_VALUE(6, NOTE_EQU_GS)     ; 51h G+7
    DEFW    MAKE_NOTE_VALUE(6, NOTE_EQU_A)      ; 52h A7    3520.000
    DEFW    MAKE_NOTE_VALUE(6, NOTE_EQU_AS)     ; 53h A+7
    DEFW    MAKE_NOTE_VALUE(6, NOTE_EQU_B)      ; 54h B7
    DEFW    MAKE_NOTE_VALUE(7, NOTE_EQU_C)      ; 55h C8    4186.009
    DEFW    MAKE_NOTE_VALUE(7, NOTE_EQU_CS)     ; 56h C+8   4434.922
    DEFW    MAKE_NOTE_VALUE(7, NOTE_EQU_D)      ; 57h D8    4698.636
    DEFW    MAKE_NOTE_VALUE(7, NOTE_EQU_DS)     ; 58h D+8   4978.032
    DEFW    MAKE_NOTE_VALUE(7, NOTE_EQU_E)      ; 59h E8    5274.041
    DEFW    MAKE_NOTE_VALUE(7, NOTE_EQU_F)      ; 5Ah F8    5587.652
    DEFW    MAKE_NOTE_VALUE(7, NOTE_EQU_FS)     ; 5Bh F+8   5919.911
    DEFW    MAKE_NOTE_VALUE(7, NOTE_EQU_G)      ; 5Ch G8    6271.927
    DEFW    MAKE_NOTE_VALUE(7, NOTE_EQU_GS)     ; 5Dh G+8   6644.875
    DEFW    MAKE_NOTE_VALUE(7, NOTE_EQU_A)      ; 5Eh A8    7040.000
    DEFW    MAKE_NOTE_VALUE(7, NOTE_EQU_AS)     ; 5Fh A+8   7458.620
                                                ;     B8    7902.133
