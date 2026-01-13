#include <kernel.h>
#include <pci.h>
#include <io.h>
#include <pit.h>
#include <string.h>

struct _pci_device_hdr pci_device_hdr[256];

//========================================================================================
/* ... */
static uint32_t pci_conf_read_dword(uint8_t bus, uint8_t slot, uint8_t func, uint8_t offset) 
{
    /* Create the 32-bit address.
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

    // Write the address to the Address Port (0xCF8).
    OUTL(CONFIG_ADDRESS, address);
    
    // Read the 32-bit data from the Data Port (0xCFC).
    return INL(CONFIG_DATA);
}

//========================================================================================
/* ... */
void pci_probe_devices()
{
    memset(&pci_device_hdr, 0, sizeof(struct _pci_device_hdr)*256);

    // Index to be used for enumerating pci headers.
    size_t index = 0;

    // Full scan of all busses.
    for(uint32_t bus = 0; bus < 256; bus++)
    {
        // ...
        for(uint32_t slot = 0; slot < 32; slot++)
        {
            // By default, assume we only need to check func 0, unless it's a multi-function device.
            uint8_t func_limit = 1;

            for(uint32_t func = 0; func < func_limit; func++)
            {
                uint32_t reg0 = pci_conf_read_dword(bus, slot, func, 0x00);
                
                // If register 0 is all ones, it means nothing is present.
                // We also ensure index is less than 256 (0-255).
                if(reg0 != 0xFFFFFFFF && index < 256)
                {
                    // Let's get some initial info for hdr_type before we decide to save or not.
                    uint32_t regC = pci_conf_read_dword(bus, slot, func, 0x0c);
                    pci_device_hdr[index].hdr_type = (regC >> 16) & 0xff;

                    // If we just read Function 0, check the Multi-Function bit (bit 7 of Header Type)
                    if(func == 0)
                    {
                        if(pci_device_hdr[index].hdr_type & 0x80)
                        {
                            func_limit = 8; // If set, probe functions 1-7 as well.
                        }
                    }

                    // We are only conserned with hdr_type(0), endpoint hdr.
                    if((pci_device_hdr[index].hdr_type & 0x7F) != 0) // Mask out the multi-function bit (0x80)
                    {
                        continue;
                    }

                    pci_device_hdr[index].vendor_id = (reg0 & 0xffff);
                    pci_device_hdr[index].device_id = (reg0 >> 16);

                    uint32_t reg4 = pci_conf_read_dword(bus, slot, func, 0x04);
                    pci_device_hdr[index].command = (reg4 & 0xffff);
                    pci_device_hdr[index].status  = (reg4 >> 16);

                    uint32_t reg8 = pci_conf_read_dword(bus, slot, func, 0x08);
                    pci_device_hdr[index].class_code  = (reg8 >> 24) & 0xff;
                    pci_device_hdr[index].subclass    = (reg8 >> 16) & 0xff;
                    pci_device_hdr[index].prog_if     = (reg8 >> 8)  & 0xff;
                    pci_device_hdr[index].revision_id = (reg8 & 0xff);

                    pci_device_hdr[index].bist            = (regC >> 24) & 0xff;
                    pci_device_hdr[index].latency_timer   = (regC >> 8)  & 0xff;
                    pci_device_hdr[index].cache_line_size = (regC & 0xff);

                    // For 32-bit Memory Space BARs, you calculate (BAR[x] & 0xFFFFFFF0)
                    // For I/O Space BARs, you calculate (BAR[x] & 0xFFFFFFFC)
                    // Am I doing this right?
                    pci_device_hdr[index].bar0 = pci_conf_read_dword(bus, slot, func, 0x10) & 0xFFFFFFFC;
                    pci_device_hdr[index].bar1 = pci_conf_read_dword(bus, slot, func, 0x14) & 0xFFFFFFFC;
                    pci_device_hdr[index].bar2 = pci_conf_read_dword(bus, slot, func, 0x18) & 0xFFFFFFFC;
                    pci_device_hdr[index].bar3 = pci_conf_read_dword(bus, slot, func, 0x1c) & 0xFFFFFFFC;
                    pci_device_hdr[index].bar4 = pci_conf_read_dword(bus, slot, func, 0x20) & 0xFFFFFFFC;
                    pci_device_hdr[index].bar5 = pci_conf_read_dword(bus, slot, func, 0x24) & 0xFFFFFFFC;

                    pci_device_hdr[index].cardbus_cis_ptr = pci_conf_read_dword(bus, slot, func, 0x28);

                    uint32_t reg2C = pci_conf_read_dword(bus, slot, func, 0x2c);
                    pci_device_hdr[index].subsys_vendor_id = (reg2C & 0xffff);
                    pci_device_hdr[index].subsystem_id     = (reg2C >> 16);

                    pci_device_hdr[index].exp_rom_base_addr = pci_conf_read_dword(bus, slot, func, 0x30);

                    uint32_t reg34 = pci_conf_read_dword(bus, slot, func, 0x34);
                    pci_device_hdr[index].capabilities_ptr = (reg34 & 0xff);

                    // ...
                    uint32_t reg3C = pci_conf_read_dword(bus, slot, func, 0x3c);
                    pci_device_hdr[index].max_latency = (reg3C >> 24) & 0xff;
                    pci_device_hdr[index].min_grant   = (reg3C >> 16) & 0xff;
                    pci_device_hdr[index].int_pin     = (reg3C >> 8) & 0xff;
                    pci_device_hdr[index].int_line    = (reg3C & 0xff);
                    
                    // ...
                    index++;
                }
                
                // If func 0 was a non-existent device, break the func loop immediately.
                else if(func == 0 && reg0 == 0xFFFFFFFF)
                {
                    break;
                }
            }
        }
    }
}

//========================================================================================
/* Iterate the PCI devices and display information. */
void pci_conf_display()
{
    pci_probe_devices();
    for(int i=0; i<256; i++)
    {
        // We know we have reached the end if vendor_id is 0.
        if(pci_device_hdr[i].vendor_id == 0)
        {
            break;
        }

        // Kind of like pciconf -l in FreeBSD.
        kprintf("class=%xh rev=%xh hdr=%xh vendor=%xh dev=%xh subvendor=%xh subdev=%xh\n", \
            pci_device_hdr[i].class_code, pci_device_hdr[i].revision_id, pci_device_hdr[i].hdr_type, pci_device_hdr[i].vendor_id, \
            pci_device_hdr[i].device_id, pci_device_hdr[i].subsys_vendor_id, pci_device_hdr[i].subsystem_id);
    }
}