#ifndef __PCI_H
#define __PCI_H     1

#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>

// Define the port addresses
#define CONFIG_ADDRESS 0xCF8
#define CONFIG_DATA    0xCFC

struct _pci_device_hdr {
    uint16_t device_id;
    uint16_t vendor_id;
    uint16_t status;
    uint16_t command;
    uint8_t  class_code;
    uint8_t  subclass;
    uint8_t  prog_if;
    uint8_t  revision_id;
    uint8_t  bist;
    uint8_t  hdr_type;
    uint8_t  latency_timer;
    uint8_t  cache_line_size;
    uint32_t bar0;
    uint32_t bar1;
    uint32_t bar2;
    uint32_t bar3;
    uint32_t bar4;
    uint32_t bar5;
    uint32_t cardbus_cis_ptr;
    uint16_t subsystem_id;
    uint16_t subsys_vendor_id;
    uint32_t exp_rom_base_addr;
    uint16_t reserved0;
    uint8_t  reserved1;
    uint8_t  capabilities_ptr;
    uint32_t reserved2;
    uint8_t  max_latency;
    uint8_t  min_grant;
    uint8_t  int_pin;
    uint8_t  int_line;
}__attribute__((packed));

extern struct _pci_device_hdr pci_device_hdr[];

extern void pci_probe_devices();
extern void pci_conf_display();

#endif  // __PCI_H