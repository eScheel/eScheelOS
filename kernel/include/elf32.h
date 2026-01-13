#ifndef __ELF32_H
#define __ELF32_H  1

#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>

struct ELF32_HDR {
	uint8_t e_ident[16];  /* File identification. */
	uint16_t e_type;      /* File type. */
	uint16_t e_machine;   /* Machine architecture. */
	uint32_t e_version;   /* ELF format version. */
	uint32_t e_entry;     /* Entry point. */
	uint32_t e_phoff;     /* Program header offset. */
	uint32_t e_shoff;     /* Section header file offset. */
	uint32_t e_flags;     /* Architecture-specific flags. */
	uint16_t e_ehsize;    /* Size of ELF header in bytes. */
	uint16_t e_phentsize; /* Size of program header entry. */
	uint16_t e_phnum;     /* Number of program header entries. */
	uint16_t e_shentsize; /* Size of section header entry. */
	uint16_t e_shnum;     /* Number of section header entries. */
	uint16_t e_shstrndx;  /* Section name strings section. */
}__attribute__((packed));

struct ELF32_PHDR {
    uint32_t p_type;      // Specifies the type of segment (e.g., PT_LOAD for loadable segments, PT_DYNAMIC for dynamic linking information).
    uint32_t p_offset;    // The offset from the beginning of the ELF file to the start of the segment's data.
    uint32_t p_vaddr;     // The virtual address where the segment should be loaded in memory.
    uint32_t p_paddr;     // The physical address (relevant for some systems, often the same as p_vaddr for typical applications).
    uint32_t p_filesz;    // The size of the segment in the ELF file.
    uint32_t p_memsz;     // The size of the segment in memory. This can be larger than p_filesz if the segment contains uninitialized data (e.g., the .bss section), which is zero-filled in memory.
    uint32_t p_flags;     // Flags indicating permissions and other attributes of the segment (e.g., PF_R for readable, PF_W for writable, PF_X for executable).
    uint32_t p_align;     // The required alignment for the segment in memory.
}__attribute__((packed));

extern uint32_t elf32_parse_and_relocate(uint8_t* );

#endif // __ELF32_H