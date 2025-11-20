# eScheelOS

eScheel Operating System.

Eventually targeted for x86_64 only.

Really just a reason to learn and write in assembly.
I'm not very good at this, and probably made some horrible design choices.
But it's fun!

BIOS boot only.
No concept of any file system. Stage2 is at lba 1 and kernel.elf is at lba 9.
Was looking at Minix3, but will probably go with FAT32 eventually to ease my way into UEFI.
If I ever decide to do all that.

-----------------------------------------------------------------------------------

Built on FreeBSD with the i386-gcc14 pkg.
Tested on Virtualbox and an eMachine T5048.

<img width="730" height="478" alt="escheelos" src="https://github.com/user-attachments/assets/188e27e4-0213-4a79-9072-026c7d165a1b" />
