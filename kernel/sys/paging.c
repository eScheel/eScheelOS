#include <kernel.h>
#include <string.h>
#include <vga.h>

/*
 * A 32-bit virtual address is split into three parts:
 *   Bits 31-22 (10 bits): Index into the Page Directory.
 *   Bits 21-12 (10 bits): Index into the Page Table.
 *   Bits 11-0  (12 bits): Offset into the final 4KiB page.
 */

/*
 * This holds 1024 Page Directory Entries (PDEs).
 * Each entry points to a Page Table.
 */
static uint32_t page_directory[1024] __attribute__((aligned(PAGE_SIZE)));

/*
 * A Page Table for the first 4MB of memory (0x0 - 0x3FFFFF)
 * This table is used for the *identity mapping*. It will be pointed to by page_directory[0].
 */
static struct page_tables {
    uint32_t page_table_ident0[1024] __attribute__((aligned(PAGE_SIZE)));
    uint32_t page_table_ident1[1024] __attribute__((aligned(PAGE_SIZE)));
    uint32_t page_table_ident2[1024] __attribute__((aligned(PAGE_SIZE)));
} pts;

/*
 * The global pointer to the physical address of the page directory.
 * This is what kernel.asm will use to load CR3.
 */
uint32_t* page_dir_phys_addr = 0;

/*
 * Initializes the paging system.
 */
void paging_init()
{
    // Clear all page structures to zero.
    // This ensures all "Present" bits are 0 by default.
    memset(page_directory,   0, sizeof(page_directory));
    //memset(page_table_ident, 0, sizeof(page_table_ident));

    // Create the Identity Mapping (0x0 -> 0x0).
    // This maps the first 4MB of virtual memory to the first 4MB of physical memory.
    // This is CRITICAL for VGA (at 0xB8000) and for the code that runs *immediately* after paging is enabled.
    for (size_t page_num = 0; page_num < 1024; page_num++)
    {
        uint32_t physical_addr = page_num * PAGE_SIZE;
        pts.page_table_ident0[page_num] = physical_addr | PTE_PRESENT | PTE_READ_WRITE;
        pts.page_table_ident1[page_num] = physical_addr | PTE_PRESENT | PTE_READ_WRITE;
        pts.page_table_ident2[page_num] = physical_addr | PTE_PRESENT | PTE_READ_WRITE;
    }

    // Link the Page Directory to the Page Tables.
    // Get the physical addresses of our static page tables.
    // Since this C code is running *before* paging, any
    // C symbol address like `&page_table_low` *is* the physical address.
    uint32_t phys_addr0  = (uint32_t)&pts.page_table_ident0;
    uint32_t phys_addr1  = (uint32_t)&pts.page_table_ident1;
    uint32_t phys_addr2  = (uint32_t)&pts.page_table_ident2;

    // Map Virtual 0x00000000 -> page_table_low
    page_directory[0] = phys_addr0 | PDE_PRESENT | PDE_READ_WRITE;  // 0x00000000
    page_directory[1] = phys_addr1 | PDE_PRESENT | PDE_READ_WRITE;  // 0x00400000
    page_directory[2] = phys_addr2 | PDE_PRESENT | PDE_READ_WRITE;  // 0x00800000


    // Store the physical address of the Page Directory
    page_dir_phys_addr = (uint32_t*)&page_directory;
}