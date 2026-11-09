.export _filesystem_start, _filesystem_end

.segment "RODATA"
_filesystem_start:
    .incbin "rootfs.tar"
_filesystem_end:
