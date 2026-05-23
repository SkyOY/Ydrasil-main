OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    IROM (rx)  : ORIGIN = 0x80000000, LENGTH = 16K
    DRAM (rwx) : ORIGIN = 0x80100000, LENGTH = 256K
}

_stack_top = ORIGIN(DRAM) + LENGTH(DRAM);

SECTIONS
{
    .text :
    {
        KEEP(*(.text.init))
        *(.text .text.*)
        *(.rodata .rodata.*)
    } > IROM

    . = ALIGN(64);
    .tohost :
    {
        . = ALIGN(64);
        PROVIDE(tohost = .);
        LONG(0);
        LONG(0);
    } > IROM

    .data :
    {
        __global_pointer$ = . + 0x800;
        *(.sdata .sdata.*)
        *(.data .data.*)
    } > DRAM

    .bss (NOLOAD) :
    {
        __bss_start = .;
        *(.sbss .sbss.*)
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    } > DRAM

    _end = .;
}
