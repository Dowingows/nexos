.setcpu "6502"

.export _nexos_write, _nexos_yield, _nexos_cat, _nexos_ls
.import _nexos_write_impl
.import _nexos_yield_impl
.import _nexos_cat_impl
.import _nexos_ls_impl

.segment "API"

; Stable address called by user code: A/X = pointer to text.
_nexos_write:
    jmp _nexos_write_impl

_nexos_yield:
    jmp _nexos_yield_impl

_nexos_cat:
    jmp _nexos_cat_impl

_nexos_ls:
    jmp _nexos_ls_impl
