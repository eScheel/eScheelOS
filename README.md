# eScheelOS

eScheel Operating System.

Eventually targeted for x86 32-bit only.

Really just a reason to learn and write in assembly.
I'm not very good at this, and probably made some horrible design choices.
But it's fun!

BIOS boot only. We've rolled our own. This was the funnest part.

Identity mapped paging with no page allocators implemented.  
Has a first fit heap allocater though.

Expects a legacy IDE controller to be found. ATA-1. Or it will halt.
Kind of FAT32 Capable. (Read Only)

Round Robin based multi-tasking using the PIT!

-----------------------------------------------------------------------------------

Built on FreeBSD with the i386-gcc14 pkg.
Tested on Virtualbox and an eMachine T5048.

<img width="730" height="478" alt="escheelos" src="https://github.com/user-attachments/assets/188e27e4-0213-4a79-9072-026c7d165a1b" />
