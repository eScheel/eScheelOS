#include <kernel.h>
#include <fat32.h>
#include <ide.h>
#include <string.h>

static struct fat32_bpb bpb;
static uint32_t fat_start_lba;      // LBA = HiddenSec + ReservedSec
static uint32_t data_start_lba;     // LBA = FAT_Start + (NumFATs * FATSz32)

/* Initializes the BPB structure. */
void fat32_init()
{
    // Allocate a buffer to read the whole sector.
    uint8_t* data = (uint8_t*)malloc(512);
    memset(data, 0, 512); 

    // Read the sector into the allocated buffer.
    ide_read_sectors(0, 0, 1, data);

    // Copy the BPB of the sector into our data structure.
    memcpy(data, &bpb, sizeof(struct fat32_bpb));

    // ...
    fat_start_lba = bpb.hidden_sectors + bpb.reserved_sectors;
    data_start_lba = fat_start_lba + (bpb.fats_count * bpb.table_size_32);

    // Free the allocated buffer.
    free(data);
}

/* ... */
void fat32_ls()
{

}