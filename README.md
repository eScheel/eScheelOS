# eScheelOS

eScheel Operating System.

Eventually targeted for x86 32-bit only.

Really just a reason to learn and write in assembly.  
I'm not very good at this, and probably made some horrible design choices.  
But it's fun!  

BIOS boot only. We've rolled our own. This was the funnest part.

Identity mapped paging with no page allocators implemented.  
Has a first fit heap allocater though.

Expects an ISA compatibility mode controller to be found. Or it will halt.  
Kind of FAT32 Capable. (Read Only)  

Round Robin based multi-tasking using the PIT!  

Built on FreeBSD with the i386-gcc14 pkg. Tested on Virtualbox and an eMachine T5048.
