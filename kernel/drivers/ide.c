#include <kernel.h>
#include <ide.h>
#include <pci.h>
#include <vga.h>
#include <string.h>
#include <pit.h> // For timer_wait

// --- Globals to store our port addresses ---
// As your pci_init notes, 0x8A means legacy mode,
// so we can safely hard-code these.
static uint16_t ide_data_port     = 0x1F0; // Primary Bus
//static uint16_t ide_control_port  = 0x3F6; // Primary Bus
//static uint16_t ide_irq           = 14;

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
            vga_prints("IDE ERROR\n");
            return(-1);
        }
        if (status & ATA_SR_DF) 
        {
            vga_prints("IDE DRIVE FAULT\n");
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
        if(status & ATA_SR_ERR) { vga_prints("IDE Error waiting for DRQ!"); return -1; }
        if(status & ATA_SR_DF)  { vga_prints("IDE Drive Fault waiting for DRQ!"); return -1; }
        if(status & ATA_SR_DRQ) { break; } // Data is ready!
    }
    return 0;
}

void ide_init()
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
        vga_prints("\nNo Legacy IDE controller found!\n");
        SYSTEM_HALT();
    }

    // 1. Select the Master drive
    OUTB(ide_data_port + ATA_REG_DRIVE, ATA_SELECT_MASTER);
    
    // 2. Reset sector counts and LBA registers (set to 0)
    OUTB(ide_data_port + ATA_REG_SECCOUNT, 0);
    OUTB(ide_data_port + ATA_REG_LBA_LOW,  0);
    OUTB(ide_data_port + ATA_REG_LBA_MID,  0);
    OUTB(ide_data_port + ATA_REG_LBA_HIGH, 0);
    
    // 3. Send the IDENTIFY command
    OUTB(ide_data_port + ATA_REG_COMMAND, ATA_CMD_IDENTIFY);
    
    // 4. Check the status port
    uint8_t status = INB(ide_data_port + ATA_REG_STATUS);
    if (status == 0) 
    {
        vga_prints("\nDrive does not exist.\n");
        SYSTEM_HALT();
    }

    // 5. Wait for BSY to clear
    while(INB(ide_data_port + ATA_REG_STATUS) & ATA_SR_BSY) {}

    // 6. Check for LBA_MID or LBA_HIGH non-zero, which means it's not ATA
    if(INB(ide_data_port + ATA_REG_LBA_MID)  != 0 \
    || INB(ide_data_port + ATA_REG_LBA_HIGH) != 0)
    {
        vga_prints("\nNot an ATA drive.\n");
        SYSTEM_HALT();
    }

    // 7. Wait for DRQ or ERR
    while(!((status = INB(ide_data_port + ATA_REG_STATUS)) & ATA_SR_DRQ) \
       && !(status & ATA_SR_ERR)) {}

    if(status & ATA_SR_ERR)
    {
        vga_prints("\nError during IDENTIFY.\n");
        SYSTEM_HALT();
    }

    // 8. Data is ready! Read 256 16-bit words
    uint16_t identify_buffer[256];
    memset(identify_buffer, 0, sizeof(identify_buffer));
    for (int i = 0; i < 256; i++) 
    {
        // We use your INW function for 16-bit reads.
        identify_buffer[i] = INW(ide_data_port + ATA_REG_DATA);
    }

    /*char *d = (char*)malloc(1024);
    memset(d, 0, 1024);
    ide_read_sectors(2, 1, d);
    for(int i=0; i<1024; i++)
    {
        vga_printc(d[i]);
    }
    free(d);*/

    //ide_write_sectors(0, 1, "This is a test string ...");
}


/*
 * Reads `num_sectors` from `lba` into `buffer`.
 * This uses Polling PIO.
 * Returns 0 on success, -1 on failure.
 * NOTE: This is a very simple, unsafe implementation.
 * It does not handle IRQs and blocks the whole CPU.
 */
int ide_read_sectors(uint32_t lba, uint8_t num_sectors, void* buffer)
{
    // Wait for the drive to be ready
    if(ide_wait_for_ready() != 0)
    {
        return -1;
    }

    // 1. Select drive (Master) and set LBA mode
    //    The 0xE0 sends 1110 (LBA mode) + Master Drive bits
    OUTB(ide_data_port + ATA_REG_DRIVE, 0xE0 | ((lba >> 24) & 0x0F));
    
    // 2. Send sector count
    OUTB(ide_data_port + ATA_REG_SECCOUNT, num_sectors);
    
    // 3. Send LBA address (in 3 parts)
    OUTB(ide_data_port + ATA_REG_LBA_LOW,  (uint8_t)(lba & 0xFF));
    OUTB(ide_data_port + ATA_REG_LBA_MID,  (uint8_t)((lba >> 8) & 0xFF));
    OUTB(ide_data_port + ATA_REG_LBA_HIGH, (uint8_t)((lba >> 16) & 0xFF));
    
    // 4. Send the READ (PIO) command
    OUTB(ide_data_port + ATA_REG_COMMAND, ATA_CMD_READ_PIO);

    // 5. Read the data, one sector at a time
    uint16_t* read_buffer = (uint16_t*)buffer;
    for (int s = 0; s < num_sectors; s++)
    {
        // Wait for the drive to be ready with the data
        while (1) 
        {
            uint8_t status = INB(ide_data_port + ATA_REG_STATUS);
            if (status & ATA_SR_ERR) { vga_prints("Read Error!"); return -1; }
            if (status & ATA_SR_DRQ) { break; } // Data is ready!
        }

        // Read 256 16-bit words (512 bytes)
        for (int i = 0; i < 256; i++)
        {
            read_buffer[i] = INW(ide_data_port + ATA_REG_DATA);
        }
        read_buffer += 256; // Move buffer pointer to next sector
    }

    return 0;
}

/*
 * Writes `num_sectors` from `lba` from `buffer`.
 *
 * *** CAUTION: THIS IS DANGEROUS! ***
 * A bug here can (and likely will) corrupt your disk or filesystem.
 * Be 100% sure you know what LBA you are writing to.
 */
int ide_write_sectors(uint32_t lba, uint8_t num_sectors, void* buffer)
{
    // Wait for the drive to be ready
    if(ide_wait_for_ready() != 0) 
    {
        return -1;
    }

    // 1. Select drive (Master) and set LBA mode
    OUTB(ide_data_port + ATA_REG_DRIVE, 0xE0 | ((lba >> 24) & 0x0F));
    
    // 2. Send sector count
    OUTB(ide_data_port + ATA_REG_SECCOUNT, num_sectors);
    
    // 3. Send LBA address (in 3 parts)
    OUTB(ide_data_port + ATA_REG_LBA_LOW,  (uint8_t)(lba & 0xFF));
    OUTB(ide_data_port + ATA_REG_LBA_MID,  (uint8_t)((lba >> 8) & 0xFF));
    OUTB(ide_data_port + ATA_REG_LBA_HIGH, (uint8_t)((lba >> 16) & 0xFF));
    
    // 4. Send the WRITE (PIO) command
    OUTB(ide_data_port + ATA_REG_COMMAND, ATA_CMD_WRITE_PIO);

    // 5. Write the data, one sector at a time
    uint16_t* write_buffer = (uint16_t*)buffer;
    for (int s = 0; s < num_sectors; s++)
    {
        // Wait for the drive to be ready *for the data* (DRQ)
        if(ide_wait_for_drq() != 0) return -1;

        // Write 256 16-bit words (512 bytes)
        for (int i = 0; i < 256; i++)
        {
            OUTW(ide_data_port + ATA_REG_DATA, write_buffer[i]);
        }
        write_buffer += 256; // Move buffer pointer to next sector
    }
    
    // 6. Wait for the write to complete
    // After the last sector is sent, the drive will be busy
    // writing. We must wait for it to be ready again.
    if (ide_wait_for_ready() != 0) 
    {
        return(-1);
    }

    return 0;
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