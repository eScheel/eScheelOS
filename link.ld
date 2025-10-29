OUTPUT_FORMAT(elf32-i386)
ENTRY(KERNEL_INIT)
SECTIONS
{
  . = 0x00100000;
  kernel_offset = .;
  .text BLOCK(4K)      : ALIGN(4K)
  {
    *(.text)
  }
  .rodata BLOCK(4K)    : ALIGN(4K)
  {
    *(.rodata)
  }
  .data BLOCK(4K)      : ALIGN(4K)
  {
    *(.data)
  }
  .bss BLOCK(4K)       : ALIGN(4K)
  {
    *(.bss)
  }
  kernel_end = .;
}
