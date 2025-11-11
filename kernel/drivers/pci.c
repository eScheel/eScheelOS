#include <kernel.h>
#include <pci.h>
#include <vga.h>
#include <pit.h>
#include <string.h>

struct _pci_device_hdr pci_device_hdr[256];

/* ... */
uint32_t pci_conf_read_dword(uint8_t bus, uint8_t slot, uint8_t func, uint8_t offset) 
{
    /* 1. Create the 32-bit address.
    The critical part is building the 32-bit integer to send to the 0xCF8 address port. It's a bit-packed field.
    31    30-24    23-16     15-11      10-8      7-2        1-0
    |      |        |         |         |         |          |
    |      |        |         |         |         |          +-- Must be 00 (for 32-bit alignment)
    |      |        |         |         |         +------------- Register Offset (0x00, 0x04, 0x08, etc.)
    |      |        |         |         +----------------------- Function Number (0-7)
    |      |        |         +--------------------------------- Device/Slot Number (0-31)
    |      |        +------------------------------------------- Bus Number (0-255)
    |      +---------------------------------------------------- Reserved (Must be 0)
    +----------------------------------------------------------- Enable Bit (Must be 1)
    */ 
    uint32_t address = 0x80000000;      // Start with the Enable Bit set. (Bit 31)
    address |= ((uint32_t)bus << 16);   // Add the Bus number (left-shifted 16 bits)
    address |= ((uint32_t)slot << 11);  // Add the Slot number (left-shifted 11 bits)
    address |= ((uint32_t)func << 8);   // Add the Function number (left-shifted 8 bits)
    address |= (offset & 0xFC);         // (offset & 0xFC) clears the last two bits (0b11111100).

    // 2. Write the address to the Address Port (0xCF8).
    OUTL(CONFIG_ADDRESS, address);
    
    // 3. Read the 32-bit data from the Data Port (0xCFC).
    return INL(CONFIG_DATA);
}

/* ... */
void pci_probe_devices()
{
    memset(&pci_device_hdr, 0, sizeof(struct _pci_device_hdr)*256);

    size_t index = 0;

    for(uint32_t bus = 0; bus < 256; bus++)
    {
        for(uint32_t slot = 0; slot < 32; slot++)
        {
            for(uint32_t func = 0; func < 8; func++)
            {
                uint32_t reg0 = pci_conf_read_dword(bus, slot, func, 0x00);
                
                // ...
                if(reg0 != 0xFFFFFFFF || index > 255)
                {
                    // ...
                    uint32_t regC = pci_conf_read_dword(bus, slot, func, 0x0c);
                    pci_device_hdr[index].hdr_type = (regC >> 16) & 0xff;

                    // ...
                    if(pci_device_hdr[index].hdr_type != 0)
                    {
                        continue;
                    }

                    // ...
                    uint32_t reg0 = pci_conf_read_dword(bus, slot, func, 0x00);
                    pci_device_hdr[index].device_id = (reg0 & 0xffff);
                    pci_device_hdr[index].vendor_id = (reg0 >> 16);

                    // ...
                    uint32_t reg4 = pci_conf_read_dword(bus, slot, func, 0x04);
                    pci_device_hdr[index].status  = (reg4 & 0xffff);
                    pci_device_hdr[index].command = (reg4 >> 16);

                    // ...
                    uint32_t reg8 = pci_conf_read_dword(bus, slot, func, 0x08);
                    pci_device_hdr[index].class_code  = (reg8 >> 24) & 0xff;
                    pci_device_hdr[index].subclass    = (reg8 >> 16) & 0xff;
                    pci_device_hdr[index].prog_if     = (reg8 >> 8)  & 0xff;
                    pci_device_hdr[index].revision_id = (reg8 & 0xff);

                    // ...
                    pci_device_hdr[index].bist            = (regC >> 24) & 0xff;
                    pci_device_hdr[index].latency_timer   = (regC >> 8)  & 0xff;
                    pci_device_hdr[index].cache_line_size = (regC & 0xff);

                    // ...
                    pci_device_hdr[index].bar0 = pci_conf_read_dword(bus, slot, func, 0x10);
                    pci_device_hdr[index].bar1 = pci_conf_read_dword(bus, slot, func, 0x14);
                    pci_device_hdr[index].bar2 = pci_conf_read_dword(bus, slot, func, 0x18);
                    pci_device_hdr[index].bar3 = pci_conf_read_dword(bus, slot, func, 0x1c);
                    pci_device_hdr[index].bar4 = pci_conf_read_dword(bus, slot, func, 0x20);
                    pci_device_hdr[index].bar5 = pci_conf_read_dword(bus, slot, func, 0x24);

                    /* TODO: Finish the rest before interrupts. */

                    // ...
                    uint32_t reg3C = pci_conf_read_dword(bus, slot, func, 0x3c);
                    /* TODO: max_latency , min_grant */
                    pci_device_hdr[index].int_pin  = (reg3C >> 8) & 0xff;
                    pci_device_hdr[index].int_line = (reg3C & 0xff);


                    // Is it an IDE?
                    if(pci_device_hdr[index].class_code == 1 && pci_device_hdr[index].subclass == 1)
                    {
                        vga_prints("\nIDE: ");
                        vga_printd(bus);
                        vga_prints(" ");
                        vga_printd(slot);
                        vga_prints(" ");
                        vga_printd(func);
                        vga_prints("  ");
                        vga_printh(pci_device_hdr[index].prog_if);
                        vga_prints("  ");
                        vga_printh(pci_device_hdr[index].bar4);
                        vga_prints("  ");
                        vga_printh(pci_device_hdr[index].int_pin);
                        vga_prints("  ");
                        vga_printh(pci_device_hdr[index].int_line);
                        vga_prints("\n");
                    }
                    /*
                    else if(class == 2 && subclass == 0)
                    {
                        vga_prints("NIC Controller detected: ");
                        vga_printd(bus);
                        vga_prints(" ");
                        vga_printd(slot);
                        vga_prints(" ");
                        vga_printd(func);
                        vga_prints("\n");
                        type = 2;                        
                    }
                    */
                    index++;
                }
            }
        }
    }
}