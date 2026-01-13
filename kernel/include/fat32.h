#ifndef __FAT32_H
#define __FAT32_H  1

#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>

struct fat32_bpb {
    uint8_t  jmp[3];
    char     oem[8];
    uint16_t bytes_per_sector;
    uint8_t  sectors_per_cluster;
    uint16_t reserved_sectors;
    uint8_t  fats_count;
    uint16_t root_entry_count;
    uint16_t total_sectors_16;
    uint8_t  media_type;
    uint16_t table_size_16;
    uint16_t sectors_per_track;
    uint16_t head_side_count;
    uint32_t hidden_sectors;
    uint32_t total_sectors_32;
    
    // FAT32 Extended Fields
    uint32_t table_size_32;
    uint16_t ext_flags;
    uint16_t fat_version;
    uint32_t root_cluster;
    uint16_t fs_info;
    uint16_t backup_boot_sector;
    uint8_t  reserved[12];
    uint8_t  drive_number;
    uint8_t  reserved1;
    uint8_t  boot_signature;
    uint32_t volume_id;
    char     volume_label[11];
    char     fat_type_label[8];
}__attribute__((packed));

struct fat32_directory_entry {
    char name[11];              // 8.3 Filename
    uint8_t attr;               // Attributes (Read-only, hidden, etc.)
    uint8_t ntres;              // Reserved for Windows NT
    uint8_t creation_tenths;    // Tenth-second creation time
    uint16_t creation_time;     // Creation time
    uint16_t creation_date;     // Creation date
    uint16_t last_access;       // Last access date
    uint16_t first_cluster_high;// High 16 bits of cluster number
    uint16_t last_write_time;   // Last modification time
    uint16_t last_write_date;   // Last modification date
    uint16_t first_cluster_low; // Low 16 bits of cluster number
    uint32_t size;              // File size in bytes
} __attribute__((packed));

typedef struct {
    uint32_t size;
    uint8_t data[];
}__attribute__((packed)) file_t;

extern void fat32_ls();
extern file_t* fat32_read(const char* );
//file_t* fat32_write(const char* , const uint8_t* , size_t);

#endif  // __FAT32_H