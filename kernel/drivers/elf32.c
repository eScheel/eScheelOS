#include <kernel.h>
#include <elf32.h>
#include <string.h>

/* ... */
uint32_t elf32_parse_and_relocate(uint8_t* base)
{
    if(base[0] == 0x7f \
    && base[1] == 'E' \
    && base[2] == 'L' \
    && base[3] == 'F')
    {
        // Get the ELF_HDR from memory.
        struct ELF32_HDR hdr;
        memcpy(base, &hdr, sizeof(struct ELF32_HDR));

        // Loop through each ELF_PHDR in memory.
        uint32_t index = sizeof(struct ELF32_HDR);
        for(int i=0; i<hdr.e_phnum; i++)
        {
            // Get the current ELF_PHDR from memory.
            struct ELF32_PHDR phdr;
            memcpy(&base[index], &phdr, sizeof(struct ELF32_PHDR));

            // For now we will only support loading executables.
            // Is it PT_LOAD?
            if(phdr.p_type == 1)
            {
                // Not a valid exec location.
                if(phdr.p_paddr < 0x300000 || phdr.p_paddr > 0x3fffff)
                {
                    return(0xfffffffe);
                }

                // dst = physical_addr , src = offset_in_hdr.
                uint8_t* dst = (uint8_t *)phdr.p_paddr;
                uint8_t* src = (uint8_t *)base + phdr.p_offset;

                // Copy the data to the physical_addr elf is expecting.
                memcpy(src, dst, phdr.p_filesz);

                // If memsz != filesz , then we will probably need to zero out bss.
                if(phdr.p_memsz != phdr.p_filesz)
                {
                    dst += phdr.p_filesz;
                    size_t bss_size = phdr.p_memsz - phdr.p_filesz;
                    memset(dst, 0, bss_size);
                }               
            }

            // Skip to the next ELF_PHDR.
            index += sizeof(struct ELF32_PHDR);
            continue;
        }

        // Let's return the entry address so the caller knows where to jump to.
        return(hdr.e_entry);
    }

    // Not a valid elf file.
    else {
        return(0xffffffff);
    }
}