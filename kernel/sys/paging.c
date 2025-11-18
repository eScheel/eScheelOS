#include <kernel.h>
#include <string.h>
#include <vga.h>

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
// Also for now we just map the first 16MB.
static struct page_tables {
    uint32_t page_table_ident0[1024] __attribute__((aligned(PAGE_SIZE)));
    uint32_t page_table_ident1[1024] __attribute__((aligned(PAGE_SIZE)));
    uint32_t page_table_ident2[1024] __attribute__((aligned(PAGE_SIZE)));
    uint32_t page_table_ident3[1024] __attribute__((aligned(PAGE_SIZE)));
}pts;

// The global pointer to the physical address of the page directory.
// This is what kernel.asm will use to load CR3.
uint32_t* page_dir_phys_addr;

/* Initializes the paging system. */
void paging_init()
{
    // Clear all page structures to zero.
    // This ensures all "Present" bits are 0 by default.
    memset(page_directory, 0, sizeof(page_directory));
    memset(&pts, 0, sizeof(pts));

    // Page Tables 4MB each. 0MB - 16MB
    uint32_t physical_addr;
    for(size_t i = 0; i < 1024; i++)
    {
        physical_addr = 0x0 + (i * PAGE_SIZE);
        pts.page_table_ident0[i] = physical_addr | PTE_PRESENT | PTE_READ_WRITE;

        physical_addr = 0x400000 + (i * PAGE_SIZE);
        pts.page_table_ident1[i] = physical_addr | PTE_PRESENT | PTE_READ_WRITE;
        
        physical_addr = 0x800000 + (i * PAGE_SIZE);
        pts.page_table_ident2[i] = physical_addr | PTE_PRESENT | PTE_READ_WRITE;
        
        physical_addr = 0xC00000 + (i * PAGE_SIZE);
        pts.page_table_ident3[i] = physical_addr | PTE_PRESENT | PTE_READ_WRITE;        
    }

    // Link the Page Directory to the Page Tables.
    // Get the physical addresses of our static page tables.
    uint32_t phys_addr[4];
    phys_addr[0] = (uint32_t)&pts.page_table_ident0;
    phys_addr[1] = (uint32_t)&pts.page_table_ident1;
    phys_addr[2] = (uint32_t)&pts.page_table_ident2;
    phys_addr[3] = (uint32_t)&pts.page_table_ident3;

    // Map the tables.
    for(size_t i=0; i<4; i++)
    {
        page_directory[i] = phys_addr[i] | PDE_PRESENT | PDE_READ_WRITE;
    }

    // Store the physical address of the Page Directory
    page_dir_phys_addr = (uint32_t*)&page_directory;
}