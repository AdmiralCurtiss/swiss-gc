#***************************************************************************
# Device indepentent Read code launch pad
#
# we have 0x1800 bytes to play with at 0x80001800 (code+data), or use above Arena Hi
# This code is placed either at 0x80001800 or Above Arena Hi (depending on the game)
#**************************************************************************

# memory map for our variables that sit at the top 0x100 of memory
.set VAR_AREA, 			0x8180	# Base location of our variables
.set VAR_DISC_1_LBA, 	-0x100	# is the base file sector for disk 1
.set VAR_DISC_2_LBA, 	-0xFC	# is the base file sector for disk 2
.set VAR_CUR_DISC_LBA, 	-0xF8	# is the currently selected disk sector
.set VAR_EXI_BUS_SPD, 	-0xF4	# is the EXI bus speed (192 = 16mhz vs 208 = 32mhz)
.set VAR_SD_TYPE, 		-0xF0	# is the Card Type (SDHC=0, SD=1)
.set VAR_EXI_FREQ, 		-0xDC	# is the EXI frequency (4 = 16mhz, 5 = 32mhz)
.set VAR_EXI_SLOT, 		-0xD8	# is the EXI slot (0 = slot a, 1 = slot b)
.set VAR_TMP1,  		-0xD4	# space for a variable if required
.set VAR_TMP2,  		-0xD0	# space for a variable if required
.set VAR_TMP3,  		-0xCC	# space for a variable if required
.set VAR_TMP4,  		-0xC8	# space for a variable if required
.set VAR_CB_ADDR,		-0xC4	# high level read callback addr
.set VAR_CB_ARG1,		-0xC0	# high level read callback r3
.set VAR_CB_ARG2,		-0xBC	# high level read callback r4
.set VAR_PROG_MODE,		-0xB8	# data/code to overwrite GXRMode obj with for 480p forcing

.section .text
	.globl main
main:
	b		setup_read_type1v1	# low style read version 1
	b		setup_read_type1v2	# low style read version 2
	b		setup_read_type1v3	# low style read version 3
	b		setup_read_type2	# read hi style
	b		os_restore_interrupts	# custom os restore interrupts which will call the dvd callback
	
# Low level read
setup_read_type1v1:
	stwu		1, -0x0028 (1)		# these are instructions we patched over, so do them here
	stw			30, 32 (1)
	mflr		0
	stw			0, 36(1)			# use this spot to save lr
	bl			setup_for_read
	# clear everything that'll go into DI regs for a 0xE0 cmd
	li     		5,	0         		# offset 0
	li      	4,	0         		# len 0
	li			3,	0  				# to this dest
	lwz			0, 36(1)
	mtlr		0
	stw			31, 36 (1)			# was patched over, do it now.
	li			0, 0				# was patched over, do it now.
	blr

setup_read_type1v2:
	stwu		1, -0x0020 (1)		# these 4 are instructions we patched over, so do them here
	stw 		31, 28 (1)
	# this read stores dst and len using:
	# stw 		3, 8 (1)  
	# mr        31, 4    
	# so we'll set it later to ours.
	mflr		31
	stw			31, 8(1)
	bl			setup_for_read
	# clear everything that'll go into DI regs for a 0xE0 cmd
	li      	5,	0         		# offset 0
	li      	4,	0         		# len 0
	li			3,	0  				# to this dest
	lwz			31, 8(1)
	mtlr		31
	stw 		3, 8 (1)  			# was patched over, do it now.
	mr        	31, 4  				# was patched over, do it now.
	blr
  
setup_read_type1v3:
	stwu    	1, -0x0028 (1)		# these are instructions we patched over, so do them here
	stw     	30, 32 (1)
	mflr	  	0
	stw	  		0, 36(1)			# use this spot to save lr
	bl	  		setup_for_read
	# clear everything that'll go into DI regs for a 0xE0 cmd
	li      	5,	0         		# offset 0
	li      	4,	0         		# len 0
	li			3,	0  				# to this dest
	lwz	  		0, 36(1)
	mtlr    	0
	stw     	31, 36 (1)			# was patched over, do it now.
	li      	0, 1				# was patched over, do it now.
	blr
	
# FST style read - so we need to add the FP.offset to the File.offset
setup_read_type2:
	stwu    	1,  -64(1)   		# grow stack frame 
	mflr    	0             		# move lr  
	stw     	0,    0(1)    		# save lr
	stw			3,	12(1)
	stw			4,	16(1)
	stw			5,	20(1)
	stw			6,	24(1)
	lwz			0,	0x30(3)			# read offset and add it to file offset (r6)
	add			6, 6, 0
	mr			3,	4				# dst
	mr			4,	5				# len
	mr			5,	6				# ofs
	bl			setup_for_read
	lwz     	0,    0(1)    		# save lr
	lwz			3,	12(1)
	lwz			4,	16(1)
	lwz			5,	20(1)
	lwz			6,	24(1)
	addi    	1,  1, 64   		# grow stack frame 
	mtlr    	0             		# move lr  
	blr
  
setup_for_read:
	cmpwi		3,		0			# no dst? return
	beqlr
	cmpwi		4,		0			# no len? return
	beqlr
	stwu		1,	-128(1) 		# grow stack frame

	mflr		0					# move lr
	stw 		0,	 	0(1)		# save lr
	stw			3,		12(1)		# save r3 - dst
	stw			4,		16(1)		# save r4 - len
	stw			5,		20(1)		# save r5 - offset
	stw 		6,		24(1)		# save r6
	stw 		7,		28(1)		# save r7
	stw 		8,		32(1)		# save r8
	stw 		9,		36(1)		# save r9
	stw 		10, 	40(1)		# save r10
	stw 		11, 	44(1)		# save r11
	stmw		16, 	48(1)		# save r16->r31

# Read from the device to the destination (device specific code called)
	bl			do_read 			# do_read(dst,size, offset);

# Flush the destination - needed?
	lwz			3,		12(1)		# load dst
	lwz			4,		16(1)		# load len
	bl			dcache_flush_icache_inv
	
# Reload regs from the game
	lwz			3,		12(1)		# load r3
	lwz			4,		16(1)		# load r4
	lwz			5,		20(1)		# load r5
	lwz 		6,		24(1)		# load r6
	lwz 		7,		28(1)		# load r7
	lwz 		8,		32(1)		# load r8
	lwz 		9,		36(1)		# load r9
	lwz 		10, 	40(1)		# load r10
	lwz 		11, 	44(1)		# load r11
	lmw			16, 	48(1)		# load r16->r31
	lwz 		0,		0(1)		# load lr
	mtlr		0					# restore lr
	addi		1,		1, 128		# kill stack frame
	blr

# Cache function
dcache_flush_icache_inv:
	clrlwi. 	5, 3, 27  # check for lower bits set in address
	beq 1f
	addi 		4, 4, 0x20 
1:
	addi 		4, 4, 0x1f
	srwi 		4, 4, 5
	mtctr 		4
2:
	dcbf 		0, 3
#	icbi 		0, 3
	addi 		3, 3, 0x20
	bdnz 		2b
	sc
	sync
	isync
	blr

# End of Cache function

os_restore_interrupts:
	stwu		1,	-0x20(1) 		# grow stack frame
	mflr		0					# move lr
	stw 		0,	 	0(1)		# save lr
	
	cmpwi	3, 0
	mfmsr	4
	beq		disable_interrupts
	
	ori		5, 4, 0x8000		# enable interrupts
	b		write_msr
disable_interrupts:
	rlwinm	5, 4, 0, 17, 15		# disable interrupts
write_msr:
	stw		5, 0x10(1)			# store msr
	
	cmpwi	3, 0
	beq		skip_cb
	
	lis		6,	VAR_AREA
	lwz		7,	VAR_CB_ADDR(6)	# load callback addr
	cmpwi	7, 0
	beq		skip_cb
	
	lwz		3,	VAR_CB_ARG1(6)	# load read length
	lwz		4,	VAR_CB_ARG2(6)	# load dvdstruct addr
	lis		5, 0
	stw		5,	VAR_CB_ADDR(6)	# clear callback
	stw		5,	VAR_CB_ARG1(6)	# clear read length
	stw		5,	VAR_CB_ARG2(6)	# clear dvdstruct addr
	mtctr	7
	bctrl					# call the callback
skip_cb:
	lwz		5, 0x10(1)		# load new msr
	mtmsr	5
	rlwinm	3, 5, 17, 31, 31	# return if they're now enabled or not
	mr		4, 3
	lwz 	0,	0(1)		# load lr
	mtlr	0				# restore lr
	addi	1,	1, 0x20		# kill stack frame
	blr
	