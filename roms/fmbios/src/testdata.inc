DATA_TOP:
    DEFW    DATA_CH_R-DATA_TOP
    DEFW    DATA_CH_1-DATA_TOP
    DEFW    DATA_CH_2-DATA_TOP
    DEFW    DATA_CH_3-DATA_TOP
    DEFW    DATA_CH_4-DATA_TOP
    DEFW    DATA_CH_5-DATA_TOP
    DEFW    DATA_CH_6-DATA_TOP

DATA_CH_R:
    DEFB    0b10011111, 15      ; volume
    DEFB    0b00111111, 60      ; key-on, delay = 60
    DEFB    0FFh                ; term

DATA_CH_1:
    DEFB    60h | 00h           ; volume
    DEFB    70h | 01h           ; inst
    DEFB    80h                 ; sus off
    DEFB    84h                 ; leg off
    DEFB    86h, 6              ; Q = 6
    DEFB    25h, 60             ; key-on, delay = 60
    DEFB    0FFh                ; term

DATA_CH_2:
    DEFB    60h | 00h           ; volume
    DEFB    70h | 01h           ; inst
    DEFB    80h                 ; sus off
    DEFB    84h                 ; leg off
    DEFB    86h, 6              ; Q = 6
    DEFB    29h, 60
    DEFB    0FFh                ; term

DATA_CH_3:
    DEFB    60h | 00h           ; volume
    DEFB    70h | 01h           ; inst
    DEFB    80h                 ; sus off
    DEFB    84h                 ; leg off
    DEFB    86h, 6              ; Q = 6
    DEFB    2Ch, 60
    DEFB    0FFh                ; term

DATA_CH_4:
    DEFB    60h | 00h           ; volume
    DEFB    70h | 01h           ; inst
    DEFB    80h                 ; sus off
    DEFB    84h                 ; leg off
    DEFB    86h, 6              ; Q = 6
    DEFB    31h, 60
    DEFB    0FFh                ; term

DATA_CH_5:
    DEFB    60h | 00h           ; volume
    DEFB    70h | 02h           ; inst
    DEFB    80h                 ; sus off
    DEFB    84h                 ; leg off
    DEFB    86h, 6              ; Q = 6
    DEFB    31h, 60
    DEFB    0FFh                ; term

DATA_CH_6:
    DEFB    60h | 00h           ; volume
    DEFB    70h | 03h           ; inst
    DEFB    80h                 ; sus off
    DEFB    84h                 ; leg off
    DEFB    86h, 6              ; Q = 6
    DEFB    29h, 60
    DEFB    0FFh                ; term
