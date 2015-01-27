org 0x07c00             ; Start address 0000:7c00 
jmp short begin_boot   ; Jump to start of boot routine & skip other data

bootmesg db "#---- welcome -----#"
pm_mesg  db "Booting ...."
redo db "redo"
dw 512                   ; Bytes per sector
db 1		    ; Sectors per cluster
dw 1		    ; Number of reserved sectors
db 2		    ; Number of FATs
dw 0x00e0	    ; Number of dirs in root
dw 0x0b40 	    ; Number of sectors in volume
db 0x0f0	               ; Media descriptor
dw 9		    ; Number of sectors per FAT
dw 18		    ; Number of sectors per track
dw 2		    ; Number of read/write sectors
dw 0		    ; Number of hidden sectors

print_mesg :
   mov ah,0x13	    ; Fn 13h of int 10h writes a whole string on screen
   mov al,0x00	    ; bit 0 determines cursor pos,0->point to start after			               ; function call,1->point to last position written
   mov bx,0x0007	    ; bh -> screen page ie 0,bl = 07 ie white on black
   mov cx,0x20	    ; Length of string here 32 
   mov dx,0x0000	    ; dh->start cursor row,dl->start cursor column
   int 0x10	    ; call bios interrupt 10h
   ret		    ; Return to calling routine

get_key :
   mov ah,0x00	  
   int 0x16              ; Get_key Fn 00h of 16h,read next character
   ret

clrscr :
   mov ax,0x0600      ; Fn 06 of int 10h,scroll window up,if al = 0 clrscr
   mov cx,0x0000      ; Clear window from 0,0 
   mov dx,0x174f      ; to 23,79
   mov bh,5	   ; fill with colour 0
   int 0x10	   ; call bios interrupt 10h
   ret

begin_boot :
   call clrscr             ; Clear the screen first
   mov bp,bootmesg     ; Set the string ptr to message location
   call print_mesg       ; Print the message
   call get_key	    ; Wait till a key is pressed
bits 16
   call clrscr	    ; Clear the screen
   mov ax,0xb800	    ; Load gs to point to video memory
   mov gs,ax	    ; We intend to display a brown A in real mode
   mov word [gs:0],0x641   ; display
   call get_key          ; Get_key again,ie display till key is pressed	
   mov bp,pm_mesg	    ; Set string pointer   	
   call print_mesg	    ; Call print_mesg subroutine   
   call get_key          ; Wait till key is pressed
   call clrscr             ; Clear the screen
   cli		    ; Clear or disable interrupts
   lgdt[gdtr]	    ; Load GDT	
   mov eax,cr0	    ; The lsb of cr0 is the protected mode bit
   or al,0x01	    ; Set protected mode bit
   mov cr0,eax	    ; Mov modified word to the control register
   jmp codesel:go_pm

bits 32
go_pm : 
   mov ax,datasel   
   mov ds,ax	       ; Initialise ds & es to data segment
   mov es,ax	
   mov ax,videosel	       ; Initialise gs to video memory
   mov gs,ax	
   mov word [gs:0],0x741 ; Display white A in protected mode
spin : jmp spin             ; Loop

bits 16
gdtr :
   dw gdt_end-gdt-1      ; Length of the gdt
   dd gdt		       ; physical address of gdt
gdt
nullsel equ $-gdt           ; $->current location,so nullsel = 0h
gdt0 		       ; Null descriptor,as per convention gdt0 is 0
   dd 0		       ; Each gdt entry is 8 bytes, so at 08h it is CS
   dd 0                      ; In all the segment descriptor is 64 bits
codesel equ $-gdt	       ; This is 8h,ie 2nd descriptor in gdt
code_gdt		       ; Code descriptor 4Gb flat segment at 0000:0000h
   dw 0x0ffff	       ; Limit 4Gb  bits 0-15 of segment descriptor
   dw 0x0000	       ; Base 0h bits 16-31 of segment descriptor (sd)
   db 0x00                  ; Base addr of seg 16-23 of 32bit addr,32-39 of sd	
   db 0x09a	       ; P,DPL(2),S,TYPE(3),A->Present bit 1,Descriptor				       ; privilege level 0-3,Segment descriptor 1 ie code	    		                  ; or data seg descriptor,Type of seg,Accessed bit
   db 0x0cf	       ; Upper 4 bits G,D,0,AVL ->1 segment len is page		                                     ; granular, 1 default operation size is 32bit seg		                              ; AVL : Available field for user or OS
                              ; Lower nibble bits 16-19 of segment limit
   db 0x00	       ; Base addr of seg 24-31 of 32bit addr,56-63 of sd
datasel equ $-gdt	       ; ie 10h, beginning of next 8 bytes for data sd
data_gdt		       ; Data descriptor 4Gb flat seg at 0000:0000h
   dw 0x0ffff	       ; Limit 4Gb
   dw 0x0000	       ; Base 0000:0000h
   db 0x00	       ; Descriptor format same as above
   db 0x092
   db 0x0cf
   db 0x00
videosel equ $-gdt	       ; ie 18h,next gdt entry
   dw 3999	       ; Limit 80*25*2-1
   dw 0x8000	       ; Base 0xb8000
   db 0x0b
   db 0x92	       ; present,ring 0,data,expand-up,writable
   db 0x00	       ; byte granularity 16 bit
   db 0x00
gdt_end

times 510-($-$$)  db 0  ; Fill bytes from present loc to 510 with 0s
              dw 0x0aa55  ; Write aa55 in bytes 511,512 to indicate that			                  ; it is a bootable sector. 
