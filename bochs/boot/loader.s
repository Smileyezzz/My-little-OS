%include "boot.inc"

section loader vstart=LOADER_BASE_ADDR 
    LOADER_STACK_TOP equ LOADER_BASE_ADDR
    jmp loader_start

    ; Build the GDT and the descriptors
    GDT_BASE:       dd  0x00000000
                    dd  0x00000000
    CODE_DESC:      dd  0x0000ffff
                    dd  DESC_CODE_HIGH4
    DATA_DESC:      dd  0x0000ffff
                    dd  DESC_DATA_HIGH4
    ; the limit of segment is (0xbffff-0xb8000)/4K = 7
    VIDEO_DESC:     dd  0x80000007
                    dd  DESC_VIDEO_HIGH4
    
    GDT_SIZE        equ $ - GDT_BASE
    GDT_LIMIT       equ GDT_SIZE - 1
    ; reserve some spaces for GDT
    times   60      dq  0   

    ; (CODE_DESC - GDT_BASE) / 8 
    SELECTOR_CODE   equ (0x0001 << 3) + TI_GDT + RPL0
    SELECTOR_DATA   equ (0x0002 << 3) + TI_GDT + RPL0
    SELECTOR_VIDEO  equ (0x0003 << 3) + TI_GDT + RPL0
    
    ; the pointer of GDT
    gdt_ptr         dw  GDT_LIMIT
                    dd  GDT_BASE
    loadermsg       db  '2 loader in real.'

loader_start:
    ; use int 0x10 to print a strings
    mov sp, LOADER_BASE_ADDR
    mov bp, loadermsg
    mov cx, 17
    mov ax, 0x1301
    mov bx, 0x001f
    mov dx, 0x1800
    int 0x10
    
    ; Three steps to enter protection mode
    ; 1'st => enable the A20 Gate
    in al, 0x92
    or al, 00000010b
    out 0x92, al
    
    ; 2'nd => load the GDT address and limit to the gdtr register
    lgdt [gdt_ptr]
    
    ; 3'rd => set the cr0's PE to 1
    mov eax, cr0
    or eax, 0x00000001
    mov cr0, eax

    jmp dword SELECTOR_CODE:p_mode_start    ; clean the pipeline or the program will crack

[bits 32]
p_mode_start:
    ; initialize the segment registers by selector
    mov ax, SELECTOR_DATA
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, LOADER_STACK_TOP
    mov ax, SELECTOR_VIDEO
    mov gs, ax
    
    mov byte [gs:160], 'P'

    jmp $
