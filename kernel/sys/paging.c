#include <kernel.h>
#include <string.h>

/*
 * A 32-bit virtual address is split into three parts:
 *   Bits 31-22 (10 bits): Index into the Page Directory.
 *   Bits 21-12 (10 bits): Index into the Page Table.
 *   Bits 11-0  (12 bits): Offset into the final 4KiB page.
 */

// This holds 1024 Page Directory Entries (PDEs).
// Each entry points to a Page Table.
static uint32_t page_directory[1024] __attribute__((aligned(PAGE_SIZE)));

// We are just going to identity map everything to keep things simple.
#define PTI_COUNT 32
static uint32_t page_table_ident[PTI_COUNT][1024] __attribute__((aligned(PAGE_SIZE)));

// The global pointer to the physical address of the page directory.
// This is what kernel.asm will use to load CR3.
uint32_t* page_dir_phys_addr;

/* Initializes the paging system. */
void paging_init()
{
    // Clear all page structures to zero.
    // This ensures all "Present" bits are 0 by default.
    memset(page_directory, 0, sizeof(page_directory));
    memset(&page_table_ident, 0, PTI_COUNT*1024);

    uint32_t physical_addr = 0;
    for(int n=0; n<PTI_COUNT; n++)
    {
        // Loop through the 1024 page tables in the directory.
        for(size_t i=0; i<1024; i++)
        {
            page_table_ident[n][i] = (physical_addr + (i * PAGE_SIZE)) | PTE_PRESENT | PTE_READ_WRITE;
        }

        // Skip to next 4MB.
        physical_addr += 0x400000;    
    }

    // Link the Page Directory to the Page Tables.
    // Get the physical addresses of our static page tables.
    // And then map the table.
    uint32_t phys_addr[PTI_COUNT];
    for(int n=0; n<PTI_COUNT; n++)
    {
        phys_addr[n] = (uint32_t)&page_table_ident[n];
        page_directory[n] = phys_addr[n] | PDE_PRESENT | PDE_READ_WRITE;
    }

    // Store the physical address of the Page Directory
    page_dir_phys_addr = (uint32_t*)&page_directory;
}