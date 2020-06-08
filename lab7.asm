.model small  

.data
    content             db " ", 128 dup ('$')
    program_name       db "program.exe", 0
    file_name          db 128 dup ('$')
    
    
    epb                dw 0 ; блок параметров
    cmd_off            dw offset content 
    cmd_seg            dw ?

    buffer             db 1
    counter            db 1

    input_error        db "Invalid args.", '$'
    file_open_error    db "Error while opening file.", '$'
    file_reading_error db "Error while reading file.", '$'
    prog_open_error    db "Error while executing external program.", '$'
    
    EPB_len dw $-epb
    dsize = $ - content    
    
.stack 100h    

.code
process_command_line macro 
    local end,error
    push cx
    push ax
    push bx
    push di
    push si
    
    mov cl, es:80h
    cmp cl, 0
    je error
    
    mov di, 81h 
    mov al, ' '
    repe scasb
    dec di
    xor si, si
    
    copy_path:
        mov al, es:[di] ; символ параметра командной строки  
        cmp al, 13 ; поиск конца строки
        je end_line
        mov file_name[si], al ; запись параметра как название входного файла
        inc si ; след символ параметров
        inc di ; след символ имени файла
        jmp copy_path
    
    end_line:
        mov file_name[si], 0
        jmp end
    
    error:
        mov ah, 9
        mov dx, offset input_error
        int 21h
        jmp program_end
    
    end:
        pop si
        pop di
        pop bx
        pop ax
        pop cx
process_command_line endm

start:
    xor ax, ax
    mov ah, 4Ah ; изменить размер блока памяти
    mov bx, (csize / 16) + 17 ; новый размер в 16-байтных параграфах
    add bx, (dsize / 16) + 17
    inc bx
    int 21h
    
    mov ax, @data
    mov ds, ax
    
    process_command_line
    
    mov ax, @data
    mov es, ax
    mov cmd_seg, ax 
    
    mov dx, offset file_name
    mov ah, 3dh ; открыть файл
    mov al, 00 ; read-only
    int 21h
    jc fopen_error
    
    mov bx, ax
    mov si, 1
    mov counter, 1
    
    read:
        mov cx, 1
        mov dx, offset buffer 
        mov ah, 3fh ; считать символ
        int 21h
        jc read_error
        cmp ax, 0
        je read_end
    
        mov al, buffer        
        cmp al, 13
        je skip 
        
        mov content[si], al
        inc si
        inc counter
        jmp read
    
    skip:
        jmp read
    
    read_end:
        mov ah, 3eh ; закрыть файл
        int 21h
    
        mov dl, counter
        mov content[0], dl
    
        mov bx, offset epb ; блок epb
        mov dx, offset program_name ; путь к файлу
        mov ax, 4b00h ; запустить программу  
        int 21h
        jb prog_error
        jmp program_end
    
    read_error:
        mov ah, 9
        mov dx, offset file_reading_error
        int 21h
        jmp program_end  
    
    fopen_error:
        mov ah,9
        mov dx,offset file_open_error
        int 21h
        jmp program_end
    
    prog_error:
        mov ah,9
        mov dx,offset prog_open_error
        int 21h
    
    program_end:
        mov ax, 4c00h
        int 21h 
csize=$-start ; длина программы
end start