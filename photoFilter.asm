.data
welcome:	.asciiz	"Welcome! Please enter the name of the file you would like to edit?  \n"
filterType:     .asciiz "Please enter the filter you would like to use.\nA list of filters are the following:\n0: Saturation, 1: Grayscale, 2: Edge-detection, 3: Brightness, 4: Hue\n"
filterPercent:    .asciiz "Now enter the percentage you want to wish to filter the image from 0 to 100\n"
header: 	.space   54 	# bitmap header data stored here 
inputFileName:	.space	128 	# name of the input file, specified by user
outname: 	.asciiz  "OUTPUT_IMAGE.bmp"
buffer:		.space	1	# just here so that there are no compile time errors

######################################################################################################
# A program to process an image with multiple different filters. 
# The input image needs to be a .bmp image and the output will be the same type.
# The filters include saturation, grayscale, edge-detection, etc.
# Authors: Shaun Howard, Emilio Colindres, Bennet Sherman, Josh Tang, Kevin Perera
#
#	$s0 - the file descriptor
#	$s1 - the size of the data section of the image (after 54 byte offset)
#######################################################################################################
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
	#move $s1, $v0
	lw		$s1, header+34		# store the size of the data section of the image
	
	
	
	#read image data into array
	li		$v0, 9		# syscall 9, allocate heap memory
	move 	        $a0, $s1	# load size of data section
	syscall
	move 	        $s2, $v0	# store the base address of the array in $s2
	
	li		$v0, 14		# syscall 14, read from file
	move 	        $a0, $s0	# load file descriptor
	move 	        $a1, $s2	# load base address of array
	move 	        $a2, $s1	# load size of data section
	syscall
	
	#close file
	move		$a0, $s0		# move the file descriptor into argument register
	li		$v0, 16			# syscall 16, close file
	syscall
	
#	li 		$v0, 10			# syscall 10, exit
#	syscall

 #we must initialize the buffer for saving edits

 
 read_filter_data:
 	la $s3, buffer
 	#add $s3,$s3,$t0
        #print filter type string
	li		$v0, 4			# syscall 4, print string
	la		$a0, filterType		# load filter selection string
	syscall
	
        #read filter type
	li		$v0, 5			# syscall 5, read integer (0 to 4)
	syscall
	
	#store filter type in $t4
	addi            $t4, $v0, 0      
	
	
	
	#************ NOW THE IMAGE IS IN AN ARRAY STARTING AT $S2 **********#
	
##########################################################################################
#IMPORTANT:
#pixel array starts at $s2. each pixel is stored as 3 hexadecimal values like 15 00 88
#the r g b values are stored backwards like b g r, i.e. b = 15, g = 00, r = 88 from above
#we must iterate through the array of pixels, each 24 bits or 3 bytes wide
#first byte = b, second byte = g, third byte = r
#hence, b would be 0($s2), g = 1($s2), and r = 2($s2), nextPixel = 3($s2)
##########################################################################################



#Perform filtering on pixel data
filter_init:
	
	# $t4 == the type of filter to run (0 for saturation, 1 for grayscale, 2 for sobel edge detection, 
	# 3 for brightness, 4 for hue)
	# $t5 == new value (between 0 and 100 percent) that filter takes
	addi $t3, $zero, -1 #no filter, just exit
	beq $t3, $t4, nothing 
	
	addi $t3, $zero, 0
	beq $zero, $t4, saturation
	
	addi $t3, $zero, 1
	beq $t3, $t4, grayscale
	
	addi $t3, $zero, 2
	#beq $t3, $t4, edge_detect
	
	addi $t3, $zero, 3
	#beq $t3, $t4, brightness
	
	addi $t3, $zero, 4
	#beq $t3, $t4, hue
	
saturation:
 
	#saturate each r g b value based on percentage given
	#min value is 0, max value is 255, use fraction of each value for new value
	#use base index for 3 values, have constants to determine bit offsets of R,G,B
        #counter starts at 0, equations like Bi = i + B, Gi = i + G, Ri = i + R
        #the idea here is to use srl and sll, dumping excess 1's from the MSB
	#load the current blue pixel value into $t6
	
	#print filter percentage string
	li		$v0, 4			# syscall 4, print string
	la		$a0, filterPercent	# load filter selection string
	syscall
	
        #read filter percentage
	li		$v0, 5			# syscall 5, read integer (0 to 100)
	syscall
	
	#store filter percentage in $t5
	addi            $t5, $v0, 0         
	
	add $t4, $zero, $zero #initialize our counter to 0
	addi $t3, $zero, 255

sat_loop:
	
	#normalize the percentage to 0 - 255 scale
	mult $t5, $t3
	div $t5, $t5, 100
	
	lb $t6, ($t7) 
	
	#increment the pixel's value
	add $t6, $t6, $t5
	
	#do this for now, can add loop to add each bit to a register and then write that 
	#at end but want to test theory first
	sb $t6, ($t7)
	
	#increment counter of the saturation loop
        addi $t4, $t4, 1
	
        #increment memory address
        addi $t7, $t7, 1
        
        #find what pixel we are at currently
        #div $t3, $t, 3
        
        #check if not at the end of the pixel array
        blt $t4, $s1, sat_loop
	
	#jump to exit
	j exit
	
	#compare $t6 with $t5, 
	
        #figure out the current value's percentage out of 256
	#divu $t3, $t6, 255
	
	#find difference between inputPercentage and currPercentage in percentages
	#sub $t3, $t5, $t3
	
        #normalize the percentage to 0 - 255 scale
	#mult $t6, $t6, 255
	
nothing:
	move $t0,$zero
	move $t1,$s2
	
nothing_loop:
	lb $t2, ($t1)
	sb $t2, ($s3)
	addi $s3,$s3,1
	addi $t1,$t1,1
	addi $t0,$t0,1
	
	blt $t0,$s1, nothing_loop
	
	li $v0, 1
	move $a0,$t2
	syscall
	
	j write_file

grayscale:
	#convert colors into grayscale
	move $t6, $s2	#load the image
	move $t0, $zero 	#b
	move $t4, $zero
	#li   $t1, 2		#g
	#li   $t2, 4 		#r	
	#average technique: we will just average the rgb values for each pixel
average_loop:
	#computes the gray value for a pixel
	#move $t3, $zero			#gray value
	lb $t0, 0($t6)
	lb $t1, 1($t6)
	lb $t2, 2($t6)
	add $t0, $t1, $t0	#add b and g
	add $t0, $t2, $t0	#add r
	div $t3, $t3, 3		#average the sum
	# stores the value of that pixel
	# move $t0($s2), $t3
	# move $t1($s2), $t3
	# move $t2($s2), $t3
	sb $t0, 0($s3)
	sb $t0, 1($s3)
	sb $t0, 2($s3)
	
	addi $t4, $t4, 3
	#increment counters to use next pixel
	#if we reach the end of the array, exit
	bge $t4, $s1, write_file
	add $t6, $t6, 3
	add $s3, $s3, 3
	#else jump to start of the loop
	j average_loop
	
edge_detect:
	#use sobel filter
	
brightness:
	#modify rgb values
	
hue:

exit:
		
write_file:
	
	#open output file
	li	$v0, 13
	la	$a0, outname
	li	$a1, 1		#1 to write, 0 to read
	li	$a2, 0
	syscall
	move	$t1, $v0	#output file descriptor in $s2
	
	li	$v0, 15		#prep $v0 for write syscall
	move 	$a0, $t1
	la	$a1, header
	addi    $a2,$zero,54
	syscall
	#write to output file
	li	$v0, 15		#prep $v0 for write syscall
	move 	$a0, $t1
	la	$a1, buffer
	move   $a2,$s1
	syscall
	
	#close file
	move	$a0, $s2
	li	$v0, 16
	syscall

leave:
	#nicely terminate program
	li 	$v0, 10
	syscall
	
# Stuff that's experimental
#	

#
#colorChanger:
#	lw	$t5, 0($t7)	#load $t7's data into $t5
#	andi	$t5, 0xFF0000		#Let's make some colors disappear
#	#sll	$t5, $t5, 5	#mult $t5 by 2^5, let's see what happens
#	andi	$t5, $t5,0xFFFFFF	#get rid of any non-24 bit results
#	sw	$t5, 0($t7)	#put the modified value back
#	addi	$t7, $t7, 4	#prep $t7 to read the next word
#	blt 	$t7, $t6, colorChanger #might be ble

