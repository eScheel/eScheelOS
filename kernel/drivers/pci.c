#include <kernel.h>
#include <pci.h>
#include <vga.h>
#include <pit.h>

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
    |      |        |         +------------------------------- Device/Slot Number (0-31)
    |      |        +----------------------------------------- Bus Number (0-255)
    |      +-------------------------------------------------- Reserved (Must be 0)
    +--------------------------------------------------------- Enable Bit (Must be 1)
    */ 
    uint32_t address = 0x80000000;      // Start with the Enable Bit (Bit 31)
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
void check_for_device()
{
    vga_printc('\n');
    for (int bus = 0; bus < 256; bus++)
    {
        for (int slot = 0; slot < 32; slot++)
        {
            for (int func = 0; func < 8; func++)
            {
                uint32_t reg0 = pci_conf_read_dword(bus, slot, func, 0x00);
                if (reg0 != 0xFFFFFFFF)
                {
                    // Device found! Store its bus, slot, and func.
                    // You can then read other registers (like 0x08)
                    // to find its Class Code and find out if it's a
                    // network card, storage controller, etc.
                    vga_prints("Found device at ");
                    vga_printd(bus);
                    vga_prints(" ");
                    vga_printd(slot);
                    vga_prints(" ");
                    vga_printd(func);
                    vga_prints("  ");

                    // Get the lower 16 bits
                    uint16_t vendorID = (reg0 & 0x0000FFFF);
                    
                    // Get the upper 16 bits (by right-shifting)
                    uint16_t deviceID = (reg0 >> 16);

                    vga_printh(vendorID);   // (For example, Vendor 0x8086 is Intel, Vendor 0x10DE is NVIDIA)
                    vga_prints("  "); 
                    vga_printh(deviceID);
                    vga_printc('\n');
                }
            }
        }
    }
}

/* ... */
void pci_init()
{
    check_for_device();
}