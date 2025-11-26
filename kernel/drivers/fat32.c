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

/* Helper: Converts a cluster number to a sector number (LBA). */
uint32_t cluster_to_lba(uint32_t cluster)
{
    // Formula: Data_Start + ((Cluster - 2) * Sectors_Per_Cluster)
    return data_start_lba + ((cluster - 2) * bpb.sectors_per_cluster);
}

/* Helper: Looks up the next cluster in the chain from the FAT. */
uint32_t get_next_cluster(uint32_t current_cluster)
{
    // Calculate the offset of this cluster's entry in the FAT (4 bytes per entry)
    uint32_t fat_offset = current_cluster * 4;
    
    // Determine which sector of the FAT contains this offset
    uint32_t fat_sector = fat_start_lba + (fat_offset / 512);
    uint32_t ent_offset = fat_offset % 512;
    
    // Read that single FAT sector
    uint32_t* table_buffer = (uint32_t*)malloc(512);
    // Assuming Drive 0 for now (Primary Master)
    ide_read_sectors(0, fat_sector, 1, table_buffer);

    // Read the entry and mask out the top 4 bits (FAT32 specific)
    uint32_t next_cluster = table_buffer[ent_offset/4] & 0x0FFFFFFF;
    
    free(table_buffer);
    return(next_cluster);
}

/* Formats the weird "8.3" filenames (e.g., "KERNEL  ELF") to "KERNEL.ELF" */
void print_formatted_name(char* name)
{
    for(int i = 0; i < 8; i++)
    {
        if(name[i] != ' ') kprintf("%c", name[i]);
    }
    if(name[8] != ' ') 
    {
        kprintf(".");
        for(int i = 8; i < 11; i++) {
            if(name[i] != ' ') kprintf("%c", name[i]);
        }
    }
}

/* Lists the files in the Root Directory. */
void fat32_ls()
{
    uint32_t current_cluster = bpb.root_cluster;
    
    // Calculate the size of one cluster in bytes
    uint32_t cluster_size = bpb.sectors_per_cluster * 512;
    
    // Allocate a buffer to hold one entire cluster of directory entries
    uint8_t* buffer = (uint8_t*)malloc(cluster_size);

    kprintf("\nListing Root Directory:\n");

    // Loop until we hit the "End of Chain" marker (>= 0x0FFFFFF8)
    while(current_cluster < 0x0FFFFFF8)
    {
        // Read the current cluster of directory data
        uint32_t lba = cluster_to_lba(current_cluster);
        if(ide_read_sectors(0, lba, bpb.sectors_per_cluster, buffer) != 0) 
        {
            kprintf("Error reading directory cluster!\n");
            break;
        }

        // Iterate through directory entries (32 bytes each)
        struct fat32_directory_entry* dir = (struct fat32_directory_entry*)buffer;
        int entries_count = cluster_size / sizeof(struct fat32_directory_entry);

        for(int i = 0; i<entries_count; i++)
        {
            // 0x00 = No more entries in this directory
            if(dir[i].name[0] == 0x00) 
            {
                free(buffer);
                return; 
            }

            // 0xE5 = Unused/Deleted entry
            if((unsigned char)dir[i].name[0] == 0xE5) continue;

            // 0x0F = Long File Name entry (Skip these for simplicity for now)
            if(dir[i].attr == 0x0F) continue;

            // Check if it's a directory (Attribute 0x10) or File
            if(dir[i].attr & 0x10) { kprintf("[DIR]  "); }
            else                   { kprintf("[FILE] "); }

            // Print the filename and size
            print_formatted_name(dir[i].name);
            kprintf("  (%d bytes)\n", dir[i].size);
        }

        // Get the next cluster in the chain
        current_cluster = get_next_cluster(current_cluster);
    }

    free(buffer);
}