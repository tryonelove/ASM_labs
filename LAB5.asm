.model small
.stack 100h
.data
          
fd dw 0                             ; ���������� �����  
  
count dw 0                          ; ���������� ����� � ����������  

filepath db 50 DUP(0)               ; ���� � �����

word_size dw 0                      ; ����� ��������� �����
is_end db 0                         ; exit(0)
char db 0                           ; ������ �� �����

line_begining_dx dw 0               ; ���������� ������ ������
line_begining_ax dw 0               ; ���������� ������ ������

string db 201                       ; ����� ��� �����
       db ?                         ; ��������� ���-�� ��������
       db 201 dup('$')              ; ���� ������
found_substr db 0                   ; ���� ������� ���������

error_sizemsg db "Invalid passed arguments", 10, 13, '$'              ; ������ ��� ������
enter_msg db "Enter string: ", 10, 13, '$'
find_err db "Can't find file!", 10, 13, 0, '$'                  ;   ������ ��� �������� ������
path_err db "Can't find file path!", 10, 13, 0, '$'          
toomany_err db "Too many opened files!", 10, 13, 0, '$'         
accessdenied_err db "Access denied!", 10, 13, 0, '$'           
string_err_msg db "Invalid string, try again: ", 10, 13, 0, '$'

.code

print macro str                            ; ����� ������
    push ax                                
    push dx
    mov dx, offset str                     ; �������� �������� ������
    mov ah, 09h                            ; ��� ����������
    int 21h                             
    pop dx                              
    pop ax
endm


print_number proc 
        push    ax
        push    bx
        push    cx
        push    dx
        push    di
 
        mov     cx, 10          ; cx - base number 
        xor     di, di          ; di - digits in number
        
        cmp     ah, 0
@convert:
        xor     dx, dx
        div     cx             
        add     dl, '0'
        inc     di
        push    dx              
        or      ax, ax
        jnz     @convert
        
@display: 
        pop     dx              ; dl = symbol
        mov     ah, 02h           
        int     21h
        dec     di              ; repeat while di<>0
        jnz     @display
 
        pop     di
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret
       
print_number endp

new_line macro
    mov dl,10
    mov ah,2
    int 21h
    mov dl,13
    mov ah,2
    int 21h
endm

changePos macro dir, newPos             ; dir - ����������� ������ (1 - ������, 0 - �������), newPos - ���-�� ����
    local cnt_change, cnt_changePos     ; ��������� ���������� ��� ���������� ������ �������
    mov ah, 42h                         ; ��� ����������
    mov al, 1                           ; 1-����� ��������� � �������� ���������, 2 - � �����, 0 - � ������
    mov bx, fd                          ; ���������� �������� �����
    mov dx, newPos                      ; ���-�� ���� ��� ������
    mov cl, 0                           ; ��� ���������
    cmp cl, dir                         ; ��������� ��� ����������� �����������
    je cnt_change                       ; ���� 0, �� �������
    
    neg dx ; ��������� �����  � ������ ����� ���� ������
    mov cx, 0FFFFh ; ������ ����� �������������
    jmp cnt_changePos
    
    cnt_change: ;  � ������ ����� ���� �������
        mov cx, 0
    
    cnt_changePos: ; ����������
        int 21h
endm


openFile proc
    jmp openFile_start 
    
    cant_find_error:                ; ������
    print find_err
    mov is_end, 1
    jmp openFile_end
    
    path_error:
        print path_err
        mov is_end, 1
        jmp openFile_end
    
    toomany_error:
        print toomany_err
        mov is_end, 1
        jmp openFile_end
    
    access_error:
        print accessdenied_err
        mov is_end, 1
        jmp openFile_end
    
    openFile_start:
        mov dx, offset filepath        ; ����
        mov al, 0                     ; ������ ��������, read-only
        mov ah, 3Dh                    ; ������� ����
        int 21h
        jc openFile_fin_err            ; ������ �������� �����, CF=1?
        mov bx, ax                     ; ��������� ���������� � bx
        mov fd, bx                 ; ��������� ���������� 
        jmp openFile_end               ; ����� �������� �����
    
    openFile_fin_err:           ; ��� ������
        cmp ax, 02h                 ; ���� �� ������
        je cant_find_error
        cmp ax, 03h                 ; ���� �� ������
        je path_error
        cmp ax, 04h                 ; ������� ����� �������� ������
        je toomany_error
        cmp ax, 05h                 ; ������ ��������
        je access_error
    
    openFile_end:
        ret
openFile endp 

handleLine proc
    call inc_count
    
    handleLine_start:
        mov ah, 42h                       ; ��� ����������
        mov al, 0                         ; lseek �� 0 �������
        mov bx, fd                    ; ����������
        mov cx, line_begining_dx          ; ���������� ������ ������ 
        mov dx, line_begining_ax          ;���������� ������ ������
        int 21h

    handleLineFor:                   ; ��������� ������
        mov bx,fd                ; ���������� �����
        mov cx,1                     ; ������ 1 ������
        mov ah,3Fh                   
        mov dx,offset char         ; ���������� ������� � char
        int 21h

        cmp ax,0                     ; EOF
        je skip_eol
        mov al,10                    ; \n
        cmp al,char
        je skip_eol
        mov al,13                    ; \r
        cmp al,char
        je skip_eol

    jmp handleLineFor

    set_end_file_0_fin:
        mov is_end,1
        jmp handleLine_fin

    skip_eol:                       ; ������� �� ����� ������
        mov bx,fd               ; ����������
        mov cx,1                    ; ������ 1 ������
        mov ah,3Fh                  
        mov dx,offset char        ; ���������� ������� � symbol
        int 21h

        cmp ax,0                    ; ax - ���-�� ������������, ���������� � ������ �����
        je set_end_file_0_fin
        
        mov al,10                   ; �������� �� ��������� \n
        cmp al,char
        je skip_eol

        mov al,13
        cmp al,char
        je skip_eol
    
    changePos 1,1                ; ���� ������ ������ ����� ������, �� ����� ����� �� 1
    
    handleLine_fin:
        ret
handleLine endp

checkLine proc                                  ; �������� ������ �� ������� ������� �����
    jmp check_start
    found_substr_fin:
        mov bx,fd
        mov cx,1 
        mov ah,3fh 
        mov dx,offset char 
        int 21h

        cmp ax,0
        je checkLine_cnt
         
        ; �������� ������� ������ �� ����� 
        mov al, char
        cmp al,' '
        je checkLine_cnt              ; ����� ����� ������/���/\n/\r - ������� ��� ����� ������
        cmp al,9
        je checkLine_cnt
        cmp al,10
        je checkLine_cnt
        cmp al,13
        je checkLine_cnt    
        jmp no_substr ; ��� - ������ ������ ������ ����� � ������
        
        checkLine_cnt:
            changePos 1,word_size
            cmp ax, 2 ; ���� ����� ������ � �����, ��� ������ �������� �� �������
            jb substring ; �������� ax < 2  
            changePos 1,1
            changePos 1,1
    
            mov bx, fd 
            mov cx, 1
            mov ah,3fh 
            mov dx,offset char
            int 21h
             
             
            ; �������� ����� �� ����� 
            mov al,char                 ;���������� ������� �� �����
            cmp al,' '
            je substring
            cmp al,9
            je substring
            cmp al,10
            je substring
            cmp al,13
            je substring
            jmp no_substr
        
        substring:
            mov found_substr,1 
            jmp checkLineEnd        ;�����,������� ������ � ���� ������.
        no_substr: 
            jmp checkLineFor        ;���������� ������ � ������
    jmp checkLineEnd

    found_substr_1:                   ; �������
        jmp found_substr_fin

    set_end_1_fin:
        mov is_end, 1
        jmp checkLineEnd

    check_start:
        mov di, offset string + 2           ; ��������� ������ � di
        mov found_substr, 0
        mov is_end, 0

    checkLineFor: ; �������� ������ �� ������� �����
        mov bx, fd
        mov cx, 1
        mov ah, 3fh ; ������� 1 ������
        mov dx,offset char
        int 21h

        cmp ax,0                      ; �������� �� ����� �����
        je set_end_1_fin

        mov al,10                     ; \n
        cmp al, char
        je checkLineEnd 
        mov al,13                     ; \r
        cmp al, char                
        je checkLineEnd

        mov al,[di]                   ; �������� �� ���������� ��������
        cmp al, char
        jne check_start

        inc di  ; ���������� ������, ���� ������� �������
        mov al,[di]
        cmp al,'$' ; �������� �� ����� 
        je found_substr_1  ; ������������ ������

    jmp checkLineFor

    checkLineEnd:
    ret
checkLine endp

inc_count proc
    inc count   
    ret   
inc_count endp

countWord proc                              ; ������ � ����� ����
    push ax
    push bx
    push cx
    push dx

    checkLines:
        
        changePos 0, 1           ; ���������� ���������� ������ ������, 1 �������
        mov line_begining_dx, dx
        dec ax
        mov line_begining_ax, ax
        changePos 1, 1

        call checkLine              ; �������� ������

        cmp is_end,1                ; ���� �� ����� ����� �����
        je countWordEnd            ; ����� �� �����

        cmp found_substr, 1         ; ���� ���� ����������
        jne checkLines

        call handleLine                     
    jmp checkLines
    
    countWordEnd:
        pop dx 
        pop cx
        pop bx
        pop ax
        new_line 
        mov ax, count
        call print_number     
        ret
countWord endp

get_str_size proc               ;����� ������ �����(��� ��������)
    mov di,offset string+1      ; � ������ �� ������ ����� ������
    mov dh,0
    mov dl,[di]
    mov word_size,0
    add word_size,dx
    ret
get_str_size endp

start:
    mov ax, @data
    mov ds, ax
    
    xor cx, cx
    mov cl, es:[80h] ; �������� �� ����� ������ - ����� ��������� ������
    
    cmp cl, 0 ; ���� ������ �� ���� � cmd
    je exit_bcsize
    cmp cl, 12  ; 13 - ����������� ������ ������
    jl exit_bcsize
    
    mov si, 81h  ; 81h - ����� ��������� ������
    xor di,di 
    
    inc si    ; ���������� ������ � cmd ����� �������� ���
    dec cl   ; skip �������, � �������� ��� skip ��-�������
    
    get_parm:              ;  ���� �����
        mov al, es:si
        mov [filepath + di] , al
        inc di
        inc si
    loop get_parm
    
    jmp string_input
    
    exit_bcsize:
        mov ah, 9
        mov dx, offset error_sizemsg
        int 21h
        jmp exit
    
    string_error:                      
        new_line
        mov ah, 9
        mov dx, offset string_err_msg
        int 21h
        new_line
        jmp string_input
    
    string_input:                         
        mov ah, 9
        mov dx, offset enter_msg
        int 21h
        mov ah, 0Ah ; buffered input
        mov dx, offset string
        int 21h                 
    
        mov si, offset string + 1
        mov cl, [si]
        mov ch, 0
        cmp cx, 0
        je  string_error 
        inc cx
        add si, cx
        mov al, '$'
        mov [si], al
    
    call get_str_size
    
    call openFile
    cmp is_end, 1
    je exit
    
    call countWord
        
    close_file:
        mov ah, 3Eh                 ; ����� �������� �����
        mov bx, fd
        int 21h 
        
    exit:
        mov ax, 4C00h
        int 21h
end start