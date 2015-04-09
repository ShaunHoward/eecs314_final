.data
welcome:	.asciiz	"Welcome! Please enter the name of the file you would like to edit?  \n"
header: 	.space   54 	# bitmap header data stored here 
inputFileName:	.space	128 	# name of the input file, specified by user
outname: 	.asciiz  "OUTPUT_IMAGE.bmp"
buffer:		.space	1	# just here so that there are no compile time errors due to funky shit


#	$s0 - the file descriptor
#	$s1 - the size of the data section of the image (after 54 byte offset)

.text
main:
	
	#print welcome string
	li		$v0, 4			# syscall 4, print string
	la		$a0, welcome		# load welcome string
	syscall
	
	#read filename
	li		$v0, 8			# syscall 8, read string
	la		$a0, inputFileName	# store string in inputFileName
	li		$a1, 128		# read at most 256 characters
	syscall
	
	# remove trailing newline
	li		$t0, '\n'		# we are looking for this character
	li		$t1, 128		# length of the inputFileName
	li		$t2, 0			# clear the current character
newLineLoop:
	beqz		$t1, newLineLoopEnd	# if end of string, jump to loop end
	subu		$t1, $t1, 1		# decrement the index
	lb		$t2, inputFileName($t1)	# load the character at current index position
	bne		$t2, $t0, newLineLoop	# if current character != '\n', jump to loop beginning
	li		$t0, 0			# else store null character
	sb		$t0, inputFileName($t1) # and overwrite newline character with null
newLineLoopEnd:
	
	#open input file
	li		$v0, 13			# syscall 13, open file
	la		$a0, inputFileName	# load filename address
	li 		$a1, 0			# read flag
	li		$a2, 0			# mode 0
	syscall
	move		$s0, $v0		# save file descriptor
	
	#read header data
	li		$v0, 14			# syscall 14, read from file
	move		$a0, $s0		# load file descriptor
	la		$a1, header		# load address to store data
	li		$a2, 54			# read 54 bytes
	syscall
	
	lw		$s1, header+34		# store the size of the data section of the images
	
	#close file
	move		$a0, $s0		# move the file descriptor into argument register
	li		$v0, 16			# syscall 16, close file
	syscall
	
	li 		$v0, 10			# syscall 10, exit
	syscall
	
#************ EXECUTION CURRENTLY ENDS HERE (funky shit not reached) **********
	
	
	
	#let's try some funky shit	
	la	$t6, buffer	#to be used as a max value
	addi	$t6, $t6, 1131654	#find the end of the buffer 
	la	$t7, buffer	#put the buffer in $s7
	addi	$t7, $t7, 0x38	#start 36 bytes ahead (THIS MIGHT BE OFF), as to not modify headers

colorChanger:
	lw	$t5, 0($t7)	#load $t7's data into $t5
	andi	$t5, 0xFF0000		#Let's make some colors disappear
	#sll	$t5, $t5, 5	#mult $t5 by 2^5, let's see what happens
	andi	$t5, $t5,0xFFFFFF	#get rid of any non-24 bit results
	sw	$t5, 0($t7)	#put the modified value back
	addi	$t7, $t7, 4	#prep $t7 to read the next word
	blt 	$t7, $t6, colorChanger #might be ble
		
	#open output file
	li	$v0, 13
	la	$a0, outname
	li	$a1, 1		#1 to write, 0 to read
	li	$a2, 0
	syscall
	move	$s2, $v0	#output file descriptor in $s2
	
	#write to output file
	li	$v0, 15		#prep $v0 for write syscall
	move 	$a0, $s2
	la	$a1, buffer
	li	$a2, 1131654
	syscall
	
	#close file
	move	$a0, $s2
	li	$v0, 16
	syscall
	
	#nicely terminate program
	li 	$v0, 10
	syscall

