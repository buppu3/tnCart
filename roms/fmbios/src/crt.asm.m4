;
; crt.asm.m4
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
        defc    CRT_ORG_CODE  = $4000
        org     CRT_ORG_CODE

        EXTERN  STATEMENT

        DB      "AB"            ; 4000h ID
ifdef ENABLE_DEBUG
        EXTERN  TEST
        DW      TEST            ; 4002h INIT
else
        DW      0000h           ; 4002h INIT
endif
        DW      0000h           ; 4004h STATEMENT
        DW      0000h           ; 4006h DEVICE
        DW      0000h           ; 4008h TEXT
        DW      0000h           ; 400Ah RESERVED
        DW      0000h           ; 400Ch RESERVED
        DW      0000h           ; 400Eh RESERVED

        DW      0000h           ; 4010h
        DW      0000h           ; 4012h
        DW      0000h           ; 4014h
        DW      0000h           ; 4016h
        DB      "PAC2OPLL"      ; 4018h

        DEFS    4110h - 4020h   ; 4020h~410Fh

        EXTERN  WRTOPL
        EXTERN  INIOPL
        EXTERN  MSTART
        EXTERN  MSTOP
        EXTERN  RDDATA
        EXTERN  OPLDRV
        EXTERN  TSTBGM

        JP      WRTOPL          ; 4110h
        JP      INIOPL          ; 4113h
        JP      MSTART          ; 4116h
        JP      MSTOP           ; 4119h
        JP      RDDATA          ; 411Ch
        JP      OPLDRV          ; 411Fh
        JP      TSTBGM          ; 4122h

        DEFS    4C00h - 4125h   ; 4125h~4BFFh

        include "inst_data.inc"
