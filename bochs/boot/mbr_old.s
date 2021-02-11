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

    jmp $               ; stuck the program

    message db "1 MBR"
    times 510-($-$$) db 0       ; padding the MBR to 510 bytes
    db 0x55, 0xaa               ; magic number
