#include <kernel.h>
#include <fat32.h>
#include <ide.h>
#include <string.h>

static struct fat32_bpb bpb;
static uint32_t fat_start_lba;      // LBA = HiddenSec + ReservedSec
static uint32_t data_start_lba;     // LBA = FAT_Start + (NumFATs * FATSz32)

//========================================================================================
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

//========================================================================================
/* Helper: Converts a cluster number to a sector number (LBA). */
uint32_t cluster_to_lba(uint32_t cluster)
{
    // Formula: Data_Start + ((Cluster - 2) * Sectors_Per_Cluster)
    return(data_start_lba + ((cluster - 2) * bpb.sectors_per_cluster));
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

    // Read the entry and mask out the top 4 bits.
    uint32_t next_cluster = table_buffer[ent_offset/4] & 0x0FFFFFFF;
    
    free(table_buffer);
    return(next_cluster);
}

/* Helper to convert FAT 8.3 name "NAME    EXT" to "name.ext" for comparison */
void fat_to_filename(const char* src, char* dest)
{
    int i, j = 0;
    
    // Copy Name (up to 8 chars)
    for(i = 0; i<8; i++) 
    {
        if(src[i] == ' ') { break; }
        dest[j++] = src[i];
    }
    
    // Add dot if extension exists
    if(src[8] != ' ') 
    {
        dest[j++] = '.';

        // Copy Extension (up to 3 chars)
        for(i = 8; i<11; i++)
        {
            if(src[i] == ' ') { break; }
            dest[j++] = src[i];
        }
    }

    dest[j] = '\0'; // Null terminate
}

//========================================================================================
/* Lists the files in the Root Directory. */
void fat32_ls()
{
    uint32_t current_cluster = bpb.root_cluster;
    
    // Calculate the size of one cluster in bytes
    uint32_t cluster_size = bpb.sectors_per_cluster * 512;
    
    // Allocate a buffer to hold one entire cluster of directory entries
    uint8_t* buffer = (uint8_t*)malloc(cluster_size);

    char formatted_name[13]; // 8 + 1 + 3 + null
    memset(formatted_name, 0, 13);

    kprintf("Listing Root Directory:\n");

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
            if((unsigned char)dir[i].name[0] == 0xE5) { continue; }

            // 0x0F = Long File Name entry
            if(dir[i].attr == 0x0F) { continue; }

            // Check if it's a directory (Attribute 0x10) or File
            if(dir[i].attr & 0x10) { kprintf("[DIR]  "); }
            else                   { kprintf("[FILE] "); }

            // Print the filename.
            fat_to_filename(dir[i].name, formatted_name);
            int index;
            for(index=0; formatted_name[index]!=0; index++)
            {
                kprintf("%c", formatted_name[index]);
            }

            // Add some padding and print size.
            for(;index<11;index++)
            {
                kprintf(" ");
            }
            kprintf(" (%d bytes)\n", dir[i].size);
        }

        // Get the next cluster in the chain
        current_cluster = get_next_cluster(current_cluster);
    }

    free(buffer);
}

//========================================================================================
/* ... */
file_t* fat32_open(const char* fname)
{
    struct fat32_directory_entry file_entry;
    int found = 0;
    
    // SEARCH FOR THE FILE
    uint32_t dir_cluster = bpb.root_cluster;
    uint32_t cluster_size_bytes = bpb.sectors_per_cluster * 512;
    uint8_t* dir_buffer = (uint8_t*)malloc(cluster_size_bytes);
    char formatted_name[13]; // 8 + 1 + 3 + null
    memset(formatted_name, 0, 13);

    while(dir_cluster < 0x0FFFFFF8 && !found)
    {
        uint32_t lba = cluster_to_lba(dir_cluster);
        if(ide_read_sectors(0, lba, bpb.sectors_per_cluster, dir_buffer) != 0) 
        {
            kprintf("Read error in directory.\n");
            free(dir_buffer);
            return((void* )0);
        }

        // Iterate through directory entries (32 bytes each)
        struct fat32_directory_entry* dir = (struct fat32_directory_entry*)dir_buffer;
        int entries_count = cluster_size_bytes / sizeof(struct fat32_directory_entry);
        for(int i = 0; i<entries_count; i++)
        {
            if(dir[i].name[0] == 0x00) { found = -1; break; }       // End of dir
            if((unsigned char)dir[i].name[0] == 0xE5) { continue; } // Deleted
            if(dir[i].attr == 0x0F) { continue; }                   // LFN
            if(dir[i].attr & 0x10) { continue; }                    // Directory

            // Convert "NAME    EXT" to "NAME.EXT"
            fat_to_filename(dir[i].name, formatted_name);

            // Compare (Case insensitive ideally, but exact match for now)
            if(strncmp(fname, formatted_name, 12) == 0)
            {
                file_entry = dir[i];
                found = 1;
                break;
            }
        }
        
        if(found == 1 || found == -1) { break; }
        dir_cluster = get_next_cluster(dir_cluster);
    }
    
    free(dir_buffer);
    if(!found || found == -1) 
    {
        kprintf("File not found: %s\n", fname);
        return((void* )0);
    }

    // READ THE FILE DATA
    // Calculate size aligned to 512 bytes to prevent buffer overflow
    uint32_t aligned_size = file_entry.size;
    if(aligned_size % 512 != 0) 
    {
        aligned_size = (aligned_size + 512) & ~(511);
    }

    // ...
    char* file_data = (char* )malloc(aligned_size);
    char* data_ptr = file_data;
    uint32_t current_file_cluster = ((uint32_t)file_entry.first_cluster_high << 16) | file_entry.first_cluster_low;
    
    uint32_t bytes_left = file_entry.size;

    while(bytes_left > 0 && current_file_cluster < 0x0FFFFFF8)
    {
        uint32_t lba = cluster_to_lba(current_file_cluster);
        
        // Read the whole cluster
        if(ide_read_sectors(0, lba, bpb.sectors_per_cluster, data_ptr) != 0) 
        {
            kprintf("Error reading file data.\n");
            free(file_data);
            return((void* )0);
        }
        
        // Note: ide_read_sectors writes full sectors. 
        // We advance our pointer by the full cluster size to keep alignment 
        // for the next read, or just track logic carefully.
        data_ptr += cluster_size_bytes; 
        
        // ...
        if(bytes_left < cluster_size_bytes) { bytes_left = 0; }
        else { bytes_left -= cluster_size_bytes; }

        // Get next cluster in the chain
        current_file_cluster = get_next_cluster(current_file_cluster);
    }

    // ..
    file_t* ret = (file_t *)malloc(sizeof(file_t) + file_entry.size);
    memset(ret, 0, sizeof(file_t)+file_entry.size);

    ret->size = file_entry.size;
    memcpy(file_data, ret->base, ret->size);

    free(file_data);
    return(ret);
}