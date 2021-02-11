%include "boot.inc"
; Initialize
; ------------------------------------------
; make sreg to be ZERO, and set the stack pointer to 0x7c00
; the graphic card address in real mode is on 0xb8000~0xbffff, and set the gs register to 0xb800
; ------------------------------------------
section MBR vstart=0x7c00
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov sp, 0x7c00
    mov ax, 0xb800
    mov gs, ax

; Clear the screen
; ------------------------------------------
; function call 0x06 is clear the screen
; ah(function call) = 0x06, al(clear to which line) = 0, so ax = 0x600
; bh = the attribution of this function call
; (cl, ch) = the left top (X, Y) position
; (dl, dh) = the right buttom (X, Y) position
; in the VGA text mode, there are 25 line and one line can only contain 80 characters. [0x18=24, 0x4f=79]
; ------------------------------------------
    mov ax, 0x600
    mov bx, 0x700
    mov cx, 0
    mov dx, 0x184f

    int 0x10

; Show the message by the graphic card
; ------------------------------------------
; the gs register is 0xb800, so the bytes would be written to address 0xb8000+
; one character has two bytes : 1'st byte is content, 2'nd byte is attribution
; ------------------------------------------
    mov byte [gs:0x00], '1'
    mov byte [gs:0x01], 0xa4    ; a is shinning green (background) and 4 is red (frontground)
    mov byte [gs:0x02], ' '
    mov byte [gs:0x03], 0xa4
    mov byte [gs:0x04], 'M'
    mov byte [gs:0x05], 0xa4
    mov byte [gs:0x06], 'B'
    mov byte [gs:0x07], 0xa4
    mov byte [gs:0x08], 'R'
    mov byte [gs:0x09], 0xa4

; use MBR to jump to the loader
; ------------------------------------------
    mov eax, LOADER_START_SECTOR ; start sector set 2 here, cause mbr is at 0 [The LBA of start sector]
    mov bx, LOADER_BASE_ADDR     ; base address set 0x900 here [The memory address to be write]
    mov cx, 1                    ; cx is the number of sectors to be read
    call rd_disk                 ; eax, bx, cx are the parameters of function rd_disk()

    jmp LOADER_BASE_ADDR

; function of reading n sectors 
; ------------------------------------------
; eax is the sector of the loader
; bx is the address where loader to be writed
; cx is the number of sectors to be read
; [ATTENTION] instructions of in and out should use dx register for I/O reg, and the normal reg should be al or ax
;             if I/O reg is 8 bits ==> use al
;             if I/O reg is 16 bits[data] ==> use ax
; ------------------------------------------
rd_disk:
    mov esi, eax                 ; backup the eax
    mov di, cx                   ; backup the cx

; 1'st step => setup the number of sectors to be read
    mov dx, 0x1f2                ; 0x1f2 is the sector count I/O reg
    mov al, cl
    out dx, al

    mov eax, esi                 ; recover the eax

; 2'nd step => setup the LBA address
    mov dx, 0x1f3                ; 0x1f3 is the LBA low I/O reg
    out dx, al

    shr eax, 8                   
    mov dx, 0x1f4                ; 0x1f4 is the LBA mid I/O reg 
    out dx, al
    
    shr eax, 8
    mov dx, 0x1f5                ; 0x1f5 is the LBA high I/O reg
    out dx, al

    shr eax, 8
    and al, 0x0f                 ; LBA 24 ~ 27 bits
    or  al, 0xe0                 ; set the LBA features
    mov dx, 0x1f6                ; 0x1f6 is the Device I/O reg
    out dx, al

; 3'rd step => setup the reading command
    mov dx, 0x1f7                ; 0x1f7 is the command I/O reg 
    mov al, 0x20                 ; 0x20 is the call of reading
    out dx, al

; 4'th step => check the device status
    .not_ready:
        nop
        in  al, dx               ; the dx is 0x1f7 here. For reading, it's status I/O reg
        and al, 0x88             ; we only need to check bit 3 adn bit 7
        cmp al, 0x08             ; if bit 7 is 1, means the disk is busy
        jnz .not_ready
          
; 5'th step => read the loader from the disk 
    mov ax, di                   ; recover the count
    mov dx, 256                  ; every sector can store 512 bytes and the data I/O reg is two bytes, so one sector should run 512/2 times
    mul dx
    mov cx, ax

    mov dx, 0x1f0
    .go_on_read:
        in ax, dx
        mov [bx], ax             ; bx is the memory address that the loader should be write
        add bx, 2
        loop .go_on_read         ; loop instruction minus 1 on cx for every time 
    ret

    times 510-($-$$) db 0        ; padding the MBR to 510 bytes
    db 0x55, 0xaa                ; magic number
