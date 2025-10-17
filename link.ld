OUTPUT_FORMAT(elf32-i386)
ENTRY(_ENTRY)
SECTIONS
{
  . = 0x00100000;
  kernel_offset = .;
  .text BLOCK(4K)      : ALIGN(4K)
  {
    *(.text)
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
