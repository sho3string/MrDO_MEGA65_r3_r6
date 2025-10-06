Mr Do! For the Mega65
=====================

Released by Universal in 1982, Mr. Do! is a fast-paced maze chase game that blends the strategic depth of Dig Dug with the kinetic urgency of Pac-Man.

You play as a circus clown armed with a bouncing power ball, tunneling through dirt to collect cherries while evading relentless enemies. The game rewards both tactical play and improvisation; whether you're carving escape routes or triggering chain reactions with falling apples.

Due to rotated framebuffer constraints and the unique video characteristics of Mr. Do!, analog video output is disabled in rotated mode to preserve HDMI clarity and prevent CRT distortion. For purists, native orientation playback remains fully supported with proper analog sync. Although analog output via VGA was initially explored by adjusting timing parameters, workaround for the lower pixel clock required for CRT compatibility meant introduced acute horizontal stretching, making the compromise unacceptable for general use.

This core is based on the
[MiSTer](https://github.com/MiSTer-devel/Arcade-MrDo_MiSTer)
Mr Do! core which itself is based on the work of [Darren Olafson] and many others (AUTHORS).

[Muse aka sho3string](https://github.com/sho3string)
ported the core to the MEGA65 in 2025.

The core uses the [MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65)
framework and [QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA) for
FAT32 support (loading ROMs, mounting disks) and for the
on-screen-menu.

How to install Mr Do! MEGA65
----------------------------

Download from here - [Download link #1](https://files.mega65.org?id=b115db76-d9a9-4a93-b751-da34c80cfe1c)

See [this site](https://sy2002.github.io/m65cores/) to understand how to install and run the core on your MEGA65.  

This core supports R3 and R6 revision boards, the zip file contains the approproiate .bit and .cor files for these revisions.  

Download ROM: Download the MAME ROM ZIP file ( mrdo.zip [Universal] )  

Extract the zip file to arcade/mrdo and move this to your MEGA65 SD card: You may either use the bottom SD card tray of the MEGA65 or the tray at the backside of the computer (the latter has precedence over the first).  

Note: Only the following files are required  
arcade/mrdo/a4-01.bin  - 8192 bytes  
arcade/mrdo/c4-02.bin  - 8192 bytes  
arcade/mrdo/e4-03.bin  - 8192 bytes  
arcade/mrdo/f4-04.bin  - 8192 bytes  
arcade/mrdo/s8-09.bin  - 4096 bytes  
arcade/mrdo/u8-10.bin  - 4096 bytes  
arcade/mrdo/r8-08.bin  - 4096 bytes  
arcade/mrdo/n8-07.bin  - 4096 bytes  
arcade/mrdo/h5-05.bin  - 4096 bytes  
arcade/mrdo/k5-06.bin  - 4096 bytes  
arcade/mrdo/u02--2.bin - 32 bytes  
arcade/mrdo/t02--3.bin - 32 bytes  
arcade/mrdo/f10--1.bin - 32 bytes  

Default DIP switch positions:  

![image](https://github.com/user-attachments/assets/c6a6c209-7fd7-4bbf-94f4-acfa8dafc7fb)
 
The above DIP configurations are the defaults used in the MEGA65 Core, so there is no need to configure these for the first time to start playing

For a description of DIPs see the following page.  

https://www.arcade-museum.com/dipswitch-settings/mr-do



