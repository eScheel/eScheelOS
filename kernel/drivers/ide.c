#include <kernel.h>
#include <pit.h>
#include <ide.h>
#include <pci.h>
#include <io.h>
#include <string.h>

// For now just hard coding these assuming legacy.
static uint16_t ide_data_port     = 0x1F0; // Primary Bus
static uint16_t ide_control_port  = 0x3F6; // Primary Bus

// Structure used for the identify blob.
// Since our ide driver is hard-coded to the Primary IDE channel's ports (0x1F0, 0x3F6), 
// we only need to worry about 128 (Master) and 129 (Slave).
struct ata_identify ata_ident[2];

// These will be used for handling situations where we try to read from a drive that is not present.
static uint8_t drives[2];

//========================================================================================
/* Waits ~400ns by reading the alternate status port 4 times. */
static void ide_delay_400ns()
{
    INB(ide_control_port + ATA_REG_ALT_STATUS);
    INB(ide_control_port + ATA_REG_ALT_STATUS);
    INB(ide_control_port + ATA_REG_ALT_STATUS);
    INB(ide_control_port + ATA_REG_ALT_STATUS);
}

//========================================================================================
/* Initialize IDE drives. */
void ide_init()
{  
    pci_probe_devices();
    int controller_found = 0;

    // Iterate all devices in the header structure until we find a controller..
    for(int i=0; i<256; i++)
    {
        // Check if the controller is for legacy IDE.
        if(pci_device_hdr[i].class_code == 1 && pci_device_hdr[i].subclass == 1)
        {
            // We are just worrying about legacy ports 0x1F0 and 0x3F6.
            if(pci_device_hdr[i].prog_if == 0x8a 
            || pci_device_hdr[i].prog_if == 0x80)
            {
                controller_found = 1;
                break;
            }
        }
    }

    // ...
    if(!controller_found) 
    {
        kprintf("No capable legacy IDE controller found.\n");
        SYSTEM_HALT();
    }

    drives[0] = 0;
    drives[1] = 0; 

    // Look for any master or slave.
    for(int i=0; i<2; i++)
    {
        uint8_t drive_select;
        if(i == 0) 
        {
            drive_select = ATA_SELECT_MASTER;
        }
        else if(i == 1)
        { 
            drive_select = ATA_SELECT_SLAVE;
        }

        // Select the drive.
        OUTB(ide_data_port + ATA_REG_DRIVE, drive_select);
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

        // Does the drive exist?
        if(status == 0) 
        {
            continue;   // Does not.
        }

        // Wait for BSY to clear
        uint32_t start_ticks = timer_get_ticks();
        uint32_t timeout = 50; // 50 ticks = approx 500ms
        while(INB(ide_data_port + ATA_REG_STATUS) & ATA_SR_BSY) 
        {
            // Check for Timeout
            if((timer_get_ticks() - start_ticks) > timeout)
            {
                kprintf("Error timed out waiting for ready!\n");
                SYSTEM_HALT();
            }
            continue; 
        }

        // Check for LBA_MID or LBA_HIGH non-zero, which means it's not ATA
        if(INB(ide_data_port + ATA_REG_LBA_MID)  != 0 \
        || INB(ide_data_port + ATA_REG_LBA_HIGH) != 0)
        {
            continue;
        }

        // Wait for DRQ or ERR
        while(!((status = INB(ide_data_port + ATA_REG_STATUS)) & ATA_SR_DRQ) \
           && !((status & ATA_SR_ERR))) { continue; }

        // Did we have an error identifying the drive?
        if(status & ATA_SR_ERR)
        {
            continue;
        }

        // Create a buffer to get the ident data from the drive.
        uint16_t identify_buffer[256];
        memset(identify_buffer, 0, sizeof(identify_buffer));

        // Loop through the 512 byte block in 16bit increments.
        for(int i = 0; i<256; i++) 
        {
            identify_buffer[i] = INW(ide_data_port + ATA_REG_DATA);
        }

        // Let's use the buffer we just captured to fill in our ident structure.
        memset(&ata_ident[i], 0, sizeof(struct ata_identify));
        memcpy(identify_buffer, &ata_ident[i], sizeof(struct ata_identify));

        drives[i] = 1;
    }
}

//========================================================================================
/* Helper function to wait for the drive to be ready */
static int ide_wait_for_ready()
{
    uint32_t start_ticks = timer_get_ticks();
    uint32_t timeout = 50; // 50 ticks = approx 500ms

    uint8_t status = 0;
    while(1) 
    {
        status = INB(ide_data_port + ATA_REG_STATUS);
        if (status & ATA_SR_ERR) { /*kprintf("\nIDE ERROR\n");*/ return(-1); }
        if (status & ATA_SR_DF)  { /*kprintf("\nIDE DRIVE FAULT\n");*/ return(-1); }
        // If BSY bit is clear and DRDY is set, it's ready
        if (!(status & ATA_SR_BSY) && (status & ATA_SR_DRDY)) {
            break;
        }

        // Check for Timeout
        if((timer_get_ticks() - start_ticks) > timeout)
        {
            kprintf("Error timed out waiting for ready!\n");
            return(-1);
        }
    }
    return 0;
}

//========================================================================================
/* Reads num_sectors from lba into buffer. This uses Polling PIO. */
int ide_read_sectors(uint8_t drive, uint32_t lba, uint8_t num_sectors, void* buffer)
{
    if(drives[drive] == 0) { return(-1); }

    // I will need to revisit this lock when I switch to interrupts on IDE.
    uint32_t ints_enabled = (EFLAGS_VALUE() & 0x200);
    asm volatile("cli");    // Disable interrupts to be safe.

    // This variable will hold 0b11100000 (Master) or 0b11110000 (Slave)
    uint8_t drive_cmd;
    if(drive == 0) // Master
    {
        drive_cmd = 0xE0;   
    } 

    if(drive == 1) // Slave
    {
        drive_cmd = 0xF0;
    }

    // Select drive (Master or Slave) and set LBA mode
    OUTB(ide_data_port + ATA_REG_DRIVE, drive_cmd | ((lba >> 24) & 0x0F));
    ide_delay_400ns();

    // After selecting a drive (writing to 0x1F6), 
    // we must wait for that specific drive to report it is ready before sending the Sector Count and LBA registers.
    if(ide_wait_for_ready() != 0) 
    { 
        if(ints_enabled) { asm volatile("sti"); }
        return(-1); 
    }
    
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
    for(int s=0; s<num_sectors; s++)
    {
        // Wait for the drive to be ready with the data
        while(1) 
        {
            uint8_t status = INB(ide_data_port + ATA_REG_STATUS);
            if (status & ATA_SR_ERR) 
            { 
                //kprintf("\nRead Error!");
                if(ints_enabled) { asm volatile("sti"); } 
                return(-1); 
            }
            if (status & ATA_SR_DRQ) { break; } // Data is ready!
        }

        // Read 256 16-bit words (512 bytes)
        for(int i = 0; i<256; i++)
        {
            read_buffer[i] = INW(ide_data_port + ATA_REG_DATA);
        }
        read_buffer += 256; // Move buffer pointer to next sector
    }

    if(ints_enabled) { asm volatile("sti"); }
    return(0);  // Success
}

//========================================================================================
/* Helper function to wait for the drive to request data (DRQ) */
static int ide_wait_for_drq()
{
    uint32_t start_ticks = timer_get_ticks();
    uint32_t timeout = 50; // 50 ticks = approx 500ms

    uint8_t status = 0;
    while(1) 
    {
        status = INB(ide_data_port + ATA_REG_STATUS);
        if(status & ATA_SR_ERR) { /*kprintf("\nIDE Error waiting for DRQ!\n");*/ return(-1); }
        if(status & ATA_SR_DF)  { /*kprintf("\nIDE Drive Fault waiting for DRQ!\n");*/ return(-1); }
        if(status & ATA_SR_DRQ) { break; } // Data is ready!

        // Check for Timeout
        if((timer_get_ticks() - start_ticks) > timeout)
        {
            kprintf("Error timed out waiting for ready!\n");
            return(-1);
        }
    }
    return 0;
}

//========================================================================================
/* Writes num_sectors from lba from buffer. */
int ide_write_sectors(uint8_t drive, uint32_t lba, uint8_t num_sectors, void* buffer)
{
    if(drives[drive] == 0) { return(-1); }

    // I will need to revisit this lock when I switch to interrupts on IDE.
    uint32_t ints_enabled = (EFLAGS_VALUE() & 0x200);
    asm volatile("cli");    // Disable interrupts to be safe.

    // This variable will hold 0b11100000 (Master) or 0b11110000 (Slave)
    uint8_t drive_cmd;
    if(drive == 0) // Master
    {
        drive_cmd = 0xE0;  
    } 

    if(drive == 1) // Slave
    {
        drive_cmd = 0xF0;
    }

    // Select drive (Master or Slave) and set LBA mode
    OUTB(ide_data_port + ATA_REG_DRIVE, drive_cmd | ((lba >> 24) & 0x0F));
    ide_delay_400ns();

    // After selecting a drive (writing to 0x1F6), 
    // we must wait for that specific drive to report it is ready before sending the Sector Count and LBA registers.
    if(ide_wait_for_ready() != 0) { 
        if(ints_enabled) { asm volatile("sti"); }
        return(-1); 
    }
    
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
    for(int s = 0; s < num_sectors; s++)
    {
        // Wait for the drive to be ready *for the data* (DRQ)
        if(ide_wait_for_drq() != 0) { 
            if(ints_enabled) { asm volatile("sti"); }
            return(-1); 
        }

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
    if(ide_wait_for_ready() != 0) { 
        if(ints_enabled) { asm volatile("sti"); }
        return(-1); 
    }

    if(ints_enabled) { asm volatile("sti"); }
    return(0);  // Success
}

//========================================================================================
// This is the function called by IRQ14_HANDLER
void ide_interrupt_handler()
{
    // TODO: Work on switching to interrupt based as opposed to polling. I am having the most trouble.
    //       Once I get tasking down to a tee, then I should come back here and work on interrupts.
    //       Because I will need to stop a specific task as opposed to the whole cpu.
    //kprintf("*");
    
    // For now, we just acknowledge the interrupt.
    // We must read the status register to clear the interrupt.
    INB(ide_data_port + ATA_REG_STATUS);
}