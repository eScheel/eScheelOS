#include <kernel.h>
#include <ide.h>
#include <pci.h>
#include <vga.h>
#include <string.h>
#include <pit.h> // For timer_wait

// For now just hard coding these assuming legacy.
static uint16_t ide_data_port     = 0x1F0; // Primary Bus
static uint16_t ide_control_port  = 0x3F6; // Primary Bus

// Structure used for the identify blob.
struct ata_identify ata_ident;

/* Waits ~400ns by reading the alternate status port 4 times. */
static void ide_delay_400ns()
{
    INB(ide_control_port + ATA_REG_ALT_STATUS);
    INB(ide_control_port + ATA_REG_ALT_STATUS);
    INB(ide_control_port + ATA_REG_ALT_STATUS);
    INB(ide_control_port + ATA_REG_ALT_STATUS);
}

/* Helper function to wait for the drive to be ready */
static int ide_wait_for_ready()
{
    uint8_t status = 0;
    while(1) 
    {
        status = INB(ide_data_port + ATA_REG_STATUS);
        
        // Check for error flags
        if (status & ATA_SR_ERR) 
        {
            vga_prints("\nIDE ERROR\n");
            return(-1);
        }
        if (status & ATA_SR_DF) 
        {
            vga_prints("\nIDE DRIVE FAULT\n");
            return(-1);
        }
        // If BSY bit is clear and DRDY is set, it's ready
        if (!(status & ATA_SR_BSY) && (status & ATA_SR_DRDY)) 
        {
            break;
        }
    }
    return 0;
}

/* Helper function to wait for the drive to request data (DRQ) */
static int ide_wait_for_drq()
{
    uint8_t status = 0;
    while(1) 
    {
        status = INB(ide_data_port + ATA_REG_STATUS);
        if(status & ATA_SR_ERR) { vga_prints("\nIDE Error waiting for DRQ!\n"); return(-1); }
        if(status & ATA_SR_DF)  { vga_prints("\nIDE Drive Fault waiting for DRQ!\n"); return(-1); }
        if(status & ATA_SR_DRQ) { break; } // Data is ready!
    }
    return 0;
}

/* 
 * Initialize IDE drives. 
 * For now this will only initialize the first ide_drive we see.
 * Hopefully its the one we want.. We will fix this later.
 */
void ide_init(uint8_t boot_drive)
{
    int device_found = 0;

    // Iterate all devices in the header structure.
    for(int i=0; i<256; i++)
    {
        // Check if the controller is for legacy IDE.
        if(pci_device_hdr[i].class_code == 1 && pci_device_hdr[i].subclass == 1)
        {
            // We are just worrying about legacy ports 0x1F0 and 0x3F6.
            if(pci_device_hdr[i].prog_if == 0x8a)
            {
                device_found = 1;
                break;
            }
        }
    }

    // ...
    if(!device_found) 
    {
        vga_prints("No capable legacy IDE controller found.\n");
        SYSTEM_HALT();
    }

    // Select the Master drive
    OUTB(ide_data_port + ATA_REG_DRIVE, ATA_SELECT_MASTER);
    ide_delay_400ns();
    
    // Reset sector counts and LBA registers (set to 0)
    OUTB(ide_data_port + ATA_REG_SECCOUNT, 0);
    OUTB(ide_data_port + ATA_REG_LBA_LOW,  0);
    OUTB(ide_data_port + ATA_REG_LBA_MID,  0);
    OUTB(ide_data_port + ATA_REG_LBA_HIGH, 0);
    
    // Send the IDENTIFY command
    OUTB(ide_data_port + ATA_REG_COMMAND, ATA_CMD_IDENTIFY);
    ide_delay_400ns();
    
    // Check the status port
    uint8_t status = INB(ide_data_port + ATA_REG_STATUS);
    if (status == 0) 
    {
        vga_prints("Drive does not exist.\n");
        SYSTEM_HALT();
    }

    // Wait for BSY to clear
    while(INB(ide_data_port + ATA_REG_STATUS) & ATA_SR_BSY) { continue; }

    // Check for LBA_MID or LBA_HIGH non-zero, which means it's not ATA
    if(INB(ide_data_port + ATA_REG_LBA_MID)  != 0 \
    || INB(ide_data_port + ATA_REG_LBA_HIGH) != 0)
    {
        vga_prints("Not an ATA drive.\n");
        SYSTEM_HALT();
    }

    // Wait for DRQ or ERR
    while(!((status = INB(ide_data_port + ATA_REG_STATUS)) & ATA_SR_DRQ) \
       && !((status & ATA_SR_ERR))) { continue; }

    // ...
    if(status & ATA_SR_ERR)
    {
        vga_prints("Error with identifying the drive.\n");
        SYSTEM_HALT();
    }

    // Create a buffer to get the ident data from the drive.
    uint16_t identify_buffer[256];
    memset(identify_buffer, 0, sizeof(identify_buffer));

    // Loop through the 512 byte block in 16bit increments.
    for (int i = 0; i < 256; i++) 
    {
        identify_buffer[i] = INW(ide_data_port + ATA_REG_DATA);
    }

    // Let's use the buffer we just captured to fill in our ident structure.
    memset(&ata_ident, 0, sizeof(struct ata_identify));
    memcpy(identify_buffer, &ata_ident, sizeof(struct ata_identify));

    // Check if bit 9 of capabilites is set for LBA28.
    if(ata_ident.capabilities & 0x200)
    {
        //vga_prints((char*)ata_ident.model_string);
        //vga_printd(ata_ident.total_sectors_28bit);
        return;
    }
    else
    {
        vga_prints("LBA28 not supported!\n");
        SYSTEM_HALT();
    }
}


/*
 * Reads num_sectors from lba into buffer. This uses Polling PIO.
 * This is a very simple, unsafe implementation. It does not handle IRQs and blocks the whole CPU.
 */
int ide_read_sectors(uint32_t lba, uint8_t num_sectors, void* buffer)
{
    // Wait for the drive to be ready
    if(ide_wait_for_ready() != 0)
    {
        return(-1);
    }

    // Select drive (Master) and set LBA mode
    // The 0xE0 sends 1110 (LBA mode) + Master Drive bits
    OUTB(ide_data_port + ATA_REG_DRIVE, 0xE0 | ((lba >> 24) & 0x0F));
    ide_delay_400ns();
    
    // Send sector count
    OUTB(ide_data_port + ATA_REG_SECCOUNT, num_sectors);
    
    // Send LBA28 address (in 3 parts)
    OUTB(ide_data_port + ATA_REG_LBA_LOW,  (uint8_t)((lba & 0xFF)));
    OUTB(ide_data_port + ATA_REG_LBA_MID,  (uint8_t)((lba >> 8) & 0xFF));
    OUTB(ide_data_port + ATA_REG_LBA_HIGH, (uint8_t)((lba >> 16) & 0xFF));
    
    // Send the READ (PIO) command
    OUTB(ide_data_port + ATA_REG_COMMAND, ATA_CMD_READ_PIO);

    // Read the data, one sector at a time
    uint16_t* read_buffer = (uint16_t*)buffer;
    for (int s = 0; s < num_sectors; s++)
    {
        // Wait for the drive to be ready with the data
        while(1) 
        {
            uint8_t status = INB(ide_data_port + ATA_REG_STATUS);
            if (status & ATA_SR_ERR) 
            { 
                vga_prints("\nRead Error!"); 
                return(-1); 
            }
            if (status & ATA_SR_DRQ) { break; } // Data is ready!
        }

        // Read 256 16-bit words (512 bytes)
        for(int i = 0; i < 256; i++)
        {
            read_buffer[i] = INW(ide_data_port + ATA_REG_DATA);
        }
        read_buffer += 256; // Move buffer pointer to next sector
    }

    // Success
    return(0);
}

/* Writes num_sectors from lba from buffer. */
int ide_write_sectors(uint32_t lba, uint8_t num_sectors, void* buffer)
{
    // Wait for the drive to be ready
    if(ide_wait_for_ready() != 0) 
    {
        return(-1);
    }

    // Select drive (Master) and set LBA mode
    OUTB(ide_data_port + ATA_REG_DRIVE, 0xE0 | ((lba >> 24) & 0x0F));
    ide_delay_400ns();
    
    // Send sector count
    OUTB(ide_data_port + ATA_REG_SECCOUNT, num_sectors);
    
    // Send LBA28 address (in 3 parts)
    OUTB(ide_data_port + ATA_REG_LBA_LOW,  (uint8_t)(lba & 0xFF));
    OUTB(ide_data_port + ATA_REG_LBA_MID,  (uint8_t)((lba >> 8) & 0xFF));
    OUTB(ide_data_port + ATA_REG_LBA_HIGH, (uint8_t)((lba >> 16) & 0xFF));
    
    // Send the WRITE (PIO) command
    OUTB(ide_data_port + ATA_REG_COMMAND, ATA_CMD_WRITE_PIO);

    // Write the data, one sector at a time.
    uint16_t* write_buffer = (uint16_t*)buffer;
    for (int s = 0; s < num_sectors; s++)
    {
        // Wait for the drive to be ready *for the data* (DRQ)
        if(ide_wait_for_drq() != 0) { return(-1); }

        // Write 256 16-bit words (512 bytes)
        for(int i = 0; i < 256; i++)
        {
            OUTW(ide_data_port + ATA_REG_DATA, write_buffer[i]);
        }
        write_buffer += 256; // Move buffer pointer to next sector
    }
    
    // Wait for the write to complete
    // After the last sector is sent, the drive will be busy
    // writing. We must wait for it to be ready again.
    if(ide_wait_for_ready() != 0) 
    {
        return(-1);
    }

    // Success
    return(0);
}

// This is the function called by IRQ14_HANDLER
void ide_interrupt_handler()
{
    // For an interrupt-driven (DMA or non-blocking PIO) driver,
    // you would set a flag here to let the waiting process know
    // the data is ready.
    
    // For now, we just acknowledge the interrupt.
    // We must read the status register to clear the interrupt.
    INB(ide_data_port + ATA_REG_STATUS);
    vga_printc('*'); //
}