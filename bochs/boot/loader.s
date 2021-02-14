%include "boot.inc"

section loader vstart=LOADER_BASE_ADDR 
    LOADER_STACK_TOP equ LOADER_BASE_ADDR

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
    
    ; total_mem_bytes records the memory capacity, and the 
    ; address here is 0xb00 cause LOADER_BASE_ADDR is 0x900
    ; and 64 descriptors (64*8) = 0x200. 
    total_mem_bytes dd  0
    ; the pointer of GDT
    gdt_ptr         dw  GDT_LIMIT
                    dd  GDT_BASE

    ; ards_nr is the count of elements in ARDS, ards_buf is the address of ARDS
    ; Here is total_mem_bytes(4bytes) + gdt_ptr(6bytes) + ards(246bytes) = 0x100
    ards_buf times 244 db 0
    ards_nr         dw  0

; the address of loader_start is LOADER_BASE_ADDR+0x300, so the mbr has to jump to here
loader_start:
    ; ---------------------------------------------------------------
    ; use 0x15 to get the info of  memory space
    ; ---------------------------------------------------------------
    xor ebx, ebx                        ; the first time's call ebx=0
    mov edx, 0x534d4150                 ; magic number 'SMAP'
    mov  di, ards_buf                   ; di points to ards
    .e820_mem_get_loop:
        mov eax, 0x0000e820             ; call e820
        mov ecx, 20                     ; every ards structure has 20 bytes
        int 0x15
        jc .e820_failed_so_try_e801     ; if carry flag not zero => error
        add di, cx                      ; di points to the next ards
        inc word [ards_nr]
        cmp ebx, 0                      ; if the return value of ebx is 0, means finished
        jnz .e820_mem_get_loop 
    ; ---------------------------------------------------------------
    ; the capacity of memory is base_address_low + length_low(32 bits)
    ; ---------------------------------------------------------------
    mov cx, [ards_nr]
    mov ebx, ards_buf
    xor edx, edx                        ; edx will store the max capacity of memory
    .find_max_mem_area:
        mov eax, [ebx]                  ; base_address_low
        add eax, [ebx+8]                ; length_low
        add ebx, 20
        cmp edx, eax
        jge .next_ards
        mov edx, eax
    .next_ards:
        loop .find_max_mem_area
        jmp .mem_get_ok 
    ; ---------------------------------------------------------------
    ; Once e820 failed, use e801
    ; ---------------------------------------------------------------
    .e820_failed_so_try_e801:
        mov ax, 0xe801
        int 0x15
        jc .e801_failed_so_try_88
        ; ---------------------------------------------------------------
        ; Check ax and cx, there are for low 16MB and the unit is 1KB
        ; ---------------------------------------------------------------
        mov cx, 0x400                   ; 1K
        mul cx
        shl edx, 16
        and eax, 0x0000ffff
        or edx, eax
        add edx, 0x100000
        mov esi, edx
        
        xor eax, eax
        mov ax, bx
        mov ecx, 0x10000
        mul ecx
        add esi, eax
        mov edx, esi
        jmp .mem_get_ok
    .e801_failed_so_try_88:
        mov ah, 0x88
        int 0x15
        ;jc .error_hit
        and eax, 0x0000ffff
        mov cx, 0x400
        mul cx
        shl edx, 16
        or edx, eax
        add edx, 0x100000
    .mem_get_ok:
        mov [total_mem_bytes], edx
    
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
