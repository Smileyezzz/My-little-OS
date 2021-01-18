; Initialize
; ------------------------------------------
; make sreg to be ZERO, and set the stack pointer to 0x7c00
; ------------------------------------------
section MBR vstart=0x7c00
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov sp, 0x7c00

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

; Get the position of the cursor
; ------------------------------------------
; function call 0x03 is get the cursor's position
; bh is the page number of the cursor
; [Output]
; (ch, cl) = (column of start, column of end)
; (dh, dl) = (column of the cursor, row of the cursor)
; ------------------------------------------
    mov ah, 3
    mov bh, 0

    int 0x10

; Print the string
; ------------------------------------------
; function call 0x13 is print the string
; ah(function call) = 0x13, al(attribution of printing) = 0x1 [the cursor move with the character which is printed]
; bh = 0 [current page number], bl = 2 [attribution of the characters, here is green front black background]
; ------------------------------------------
    mov ax, message
    mov bp, ax          ; move the message to the stack base
    mov cx, 5
    mov ax, 0x1301
    mov bx, 0x2

    int 0x10

    jmp $               ; stuck the program

    message db "1 MBR"
    times 510-($-$$) db 0       ; padding the MBR to 510 bytes
    db 0x55, 0xaa               ; magic number
