New Command for Hacking JOSH Operating System
=======
Note: Read "ReadMe.pdf" for more details.

JOSH is an Operating System which can boot from a FAT12 disk (from a floppy disk). In this report, it
includes that how am I implement a new command to the operating system to show Hardware Information.

These are the Information given by the Implemented command.
• Processor Family
• Processor Model Identifier
• Processor Stepping
• Processor Vendor Identifier
• Processor Model
• RAM size
• L2 Cache Size
• Number of Floppy Drives
• Number of Hard Disk Drives
• Number of Serial Ports
• Number of Parallel Ports
• Availability of Mouse
There were few available options to get the hardware information of the system. They were,
• CPUID command
• Calling BIOS Interrupts