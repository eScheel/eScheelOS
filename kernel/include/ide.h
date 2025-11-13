#ifndef __IDE_H
#define __IDE_H     1

#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>

// --- I/O Port Offsets for Primary ATA Bus ---
// These are offsets from the base port (0x1F0)
#define ATA_REG_DATA       0x00
#define ATA_REG_ERROR      0x01
#define ATA_REG_FEATURES   0x01
#define ATA_REG_SECCOUNT   0x02
#define ATA_REG_LBA_LOW    0x03
#define ATA_REG_LBA_MID    0x04
#define ATA_REG_LBA_HIGH   0x05
#define ATA_REG_DRIVE      0x06 // Selects Drive (Master/Slave)
#define ATA_REG_STATUS     0x07
#define ATA_REG_COMMAND    0x07

// These are offsets from the control port (0x3F6)
#define ATA_REG_ALT_STATUS 0x00
#define ATA_REG_DEV_CTRL   0x00

// --- Status Register Bits ---
#define ATA_SR_BSY         0x80    // Busy
#define ATA_SR_DRDY        0x40    // Drive Ready
#define ATA_SR_DF          0x20    // Drive Fault
#define ATA_SR_ERR         0x01    // Error
#define ATA_SR_DRQ         0x08    // Data Request Ready

// --- Commands ---
#define ATA_CMD_READ_PIO   0x20
#define ATA_CMD_WRITE_PIO  0x30
#define ATA_CMD_IDENTIFY   0xEC

// --- Drive Selection ---
#define ATA_SELECT_MASTER  0xA0
#define ATA_SELECT_SLAVE   0xB0

// --- New IDENTIFY structure ---
// Represents the 512-byte data block returned by ATA_CMD_IDENTIFY
struct ata_identify_device {
    uint16_t config;                // Word 0
    uint16_t cylinders;             // Word 1
    uint16_t reserved2;             // Word 2
    uint16_t heads;                 // Word 3
    uint16_t reserved4;             // Word 4
    uint16_t reserved5;             // Word 5
    uint16_t sectors_per_track;     // Word 6
    uint16_t reserved7;             // Word 7
    uint16_t reserved8;             // Word 8
    uint16_t serial_number[10];     // Word 10-19
    uint16_t reserved20;            // Word 20
    uint16_t reserved21;            // Word 21
    uint16_t reserved22;            // <-- ADD THIS MISSING WORD
    uint16_t firmware_revision[4];  // Word 23-26
    uint16_t model_string[20];      // Word 27-46 (40 bytes)
    uint16_t reserved47;            // Word 47
    uint16_t reserved48;            // Word 48
    uint16_t capabilities;          // Word 49 (Bit 9 = LBA support)
    uint16_t reserved50;            // Word 50
    uint16_t pio_timing_mode;       // Word 51
    uint16_t reserved52;            // Word 52
    uint16_t valid_fields;          // Word 53
    uint16_t reserved54_58[5];      // Word 54-58
    uint16_t reserved59;            // Word 59
    uint32_t total_sectors_28bit;   // Word 60-61 (32-bit value)
    uint16_t reserved62_82[21];     // Word 62-82
    uint16_t command_sets_supported; // Word 83 (Bit 10 = LBA48 support)
    uint16_t reserved84_99[16];     // Word 84-99
    uint64_t total_sectors_48bit;   // Word 100-103 (64-bit value)
    // ... (the rest is irrelevant for now) ...
} __attribute__((packed));

int ide_read_sectors(uint32_t lba, uint8_t num_sectors, void* buffer);
int ide_write_sectors(uint32_t lba, uint8_t num_sectors, void* buffer);

#endif // __IDE_H