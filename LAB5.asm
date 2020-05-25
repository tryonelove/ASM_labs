.model small
.stack 100h
.data
          
fd dw 0                             ; дескриптор файла  
  
count dw 0                          ; количество строк с подстрокой  

filepath db 50 DUP(0)               ; путь к файлу

word_size dw 0                      ; длина ключевого слова
is_end db 0                         ; exit(0)
char db 0                           ; символ из файла

line_begining_dx dw 0               ; координата начала строки
line_begining_ax dw 0               ; координата начала строки

string db 201                       ; слово для ввода
       db ?                         ; введенное кол-во символов
       db 201 dup('$')              ; сама строка
found_substr db 0                   ; флаг наличия подстроки

error_sizemsg db "Invalid passed arguments", 10, 13, '$'              ; строки для вывода
enter_msg db "Enter string: ", 10, 13, '$'
find_err db "Can't find file!", 10, 13, 0, '$'                  ;   ошибки при открытии файлов
path_err db "Can't find file path!", 10, 13, 0, '$'          
toomany_err db "Too many opened files!", 10, 13, 0, '$'         
accessdenied_err db "Access denied!", 10, 13, 0, '$'           
string_err_msg db "Invalid string, try again: ", 10, 13, 0, '$'

.code

print macro str                            ; вывод строки
    push ax                                
    push dx
    mov dx, offset str                     ; смещение выходной строки
    mov ah, 09h                            ; код прерывания
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

changePos macro dir, newPos             ; dir - направление сдвига (1 - налево, 0 - направо), newPos - кол-во байт
    local cnt_change, cnt_changePos     ; локальные переменные для корректной работы макроса
    mov ah, 42h                         ; код прерывания
    mov al, 1                           ; 1-сдвиг указателя с текущего положения, 2 - с конца, 0 - с начала
    mov bx, fd                          ; дескриптор входного файла
    mov dx, newPos                      ; кол-во байт для сдвига
    mov cl, 0                           ; для сравнения
    cmp cl, dir                         ; сравнения для определения направления
    je cnt_change                       ; если 0, то направо
    
    neg dx ; изменение знака  в случае когда идем налево
    mov cx, 0FFFFh ; делаем число отрицательным
    jmp cnt_changePos
    
    cnt_change: ;  в случае когда идем направо
        mov cx, 0
    
    cnt_changePos: ; завершение
        int 21h
endm


openFile proc
    jmp openFile_start 
    
    cant_find_error:                ; ошибки
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
        mov dx, offset filepath        ; путь
        mov al, 0                     ; способ открытия, read-only
        mov ah, 3Dh                    ; открыть файл
        int 21h
        jc openFile_fin_err            ; ошибка открытия файла, CF=1?
        mov bx, ax                     ; сохраняем дискриптор в bx
        mov fd, bx                 ; сохраняем дискриптор 
        jmp openFile_end               ; конец открытия файла
    
    openFile_fin_err:           ; код ошибки
        cmp ax, 02h                 ; файл не найден
        je cant_find_error
        cmp ax, 03h                 ; путь не найден
        je path_error
        cmp ax, 04h                 ; слишком много открытых файлов
        je toomany_error
        cmp ax, 05h                 ; доступ запрещен
        je access_error
    
    openFile_end:
        ret
openFile endp 

handleLine proc
    call inc_count
    
    handleLine_start:
        mov ah, 42h                       ; код прерывания
        mov al, 0                         ; lseek на 0 позицию
        mov bx, fd                    ; дескриптор
        mov cx, line_begining_dx          ; координату начала строки 
        mov dx, line_begining_ax          ;координату начала строки
        int 21h

    handleLineFor:                   ; обработка строки
        mov bx,fd                ; дескриптор файла
        mov cx,1                     ; читаем 1 символ
        mov ah,3Fh                   
        mov dx,offset char         ; сохранение символа в char
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

    skip_eol:                       ; переход на новую строку
        mov bx,fd               ; дескриптор
        mov cx,1                    ; читаем 1 символ
        mov ah,3Fh                  
        mov dx,offset char        ; сохранение символа в symbol
        int 21h

        cmp ax,0                    ; ax - кол-во прочитанного, сравниваем с концом файла
        je set_end_file_0_fin
        
        mov al,10                   ; проверка на несколько \n
        cmp al,char
        je skip_eol

        mov al,13
        cmp al,char
        je skip_eol
    
    changePos 1,1                ; если начали читать новую строку, то свдиг влево на 1
    
    handleLine_fin:
        ret
handleLine endp

checkLine proc                                  ; проверка строки на наличие нужного слова
    jmp check_start
    found_substr_fin:
        mov bx,fd
        mov cx,1 
        mov ah,3fh 
        mov dx,offset char 
        int 21h

        cmp ax,0
        je checkLine_cnt
         
        ; проверка символа справа от слова 
        mov al, char
        cmp al,' '
        je checkLine_cnt              ; после слова пробел/таб/\n/\r - смотрим что перед словом
        cmp al,9
        je checkLine_cnt
        cmp al,10
        je checkLine_cnt
        cmp al,13
        je checkLine_cnt    
        jmp no_substr ; нет - уходим дальше искать слово в строке
        
        checkLine_cnt:
            changePos 1,word_size
            cmp ax, 2 ; если слово первое в файле, нам нельзя выходить за пределы
            jb substring ; проверка ax < 2  
            changePos 1,1
            changePos 1,1
    
            mov bx, fd 
            mov cx, 1
            mov ah,3fh 
            mov dx,offset char
            int 21h
             
             
            ; проверка слева от слова 
            mov al,char                 ;сравниваем символы ДО слова
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
            jmp checkLineEnd        ;нашли,выходим писать и идем дальше.
        no_substr: 
            jmp checkLineFor        ;продолжаем искать в строке
    jmp checkLineEnd

    found_substr_1:                   ; костыль
        jmp found_substr_fin

    set_end_1_fin:
        mov is_end, 1
        jmp checkLineEnd

    check_start:
        mov di, offset string + 2           ; загружаем строку в di
        mov found_substr, 0
        mov is_end, 0

    checkLineFor: ; проверка строки на наличие слова
        mov bx, fd
        mov cx, 1
        mov ah, 3fh ; считать 1 символ
        mov dx,offset char
        int 21h

        cmp ax,0                      ; проверка на конец файла
        je set_end_1_fin

        mov al,10                     ; \n
        cmp al, char
        je checkLineEnd 
        mov al,13                     ; \r
        cmp al, char                
        je checkLineEnd

        mov al,[di]                   ; проверка на совпадение символов
        cmp al, char
        jne check_start

        inc di  ; сравниваем дальше, если символы совпали
        mov al,[di]
        cmp al,'$' ; проверка на конец 
        je found_substr_1  ; переписываем строку

    jmp checkLineFor

    checkLineEnd:
    ret
checkLine endp

inc_count proc
    inc count   
    ret   
inc_count endp

countWord proc                              ; запись в новый файл
    push ax
    push bx
    push cx
    push dx

    checkLines:
        
        changePos 0, 1           ; сохранение координаты начала строки, 1 направо
        mov line_begining_dx, dx
        dec ax
        mov line_begining_ax, ax
        changePos 1, 1

        call checkLine              ; проверка строки

        cmp is_end,1                ; если до конца файла дошли
        je countWordEnd            ; выход из проги

        cmp found_substr, 1         ; если надо переписать
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

get_str_size proc               ;берем размер слова(для проверок)
    mov di,offset string+1      ; а размер во втором байте строки
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
    mov cl, es:[80h] ; значение по этому адресу - длина командной строки
    
    cmp cl, 0 ; если ничего не ввел в cmd
    je exit_bcsize
    cmp cl, 12  ; 13 - минимальный размер строки
    jl exit_bcsize
    
    mov si, 81h  ; 81h - адрес командной строки
    xor di,di 
    
    inc si    ; пропускаем пробел в cmd после названия ехе
    dec cl   ; skip пробела, а название ехе skip по-дефолту
    
    get_parm:              ;  путь файла
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
        mov ah, 3Eh                 ; метка закрытия файла
        mov bx, fd
        int 21h 
        
    exit:
        mov ax, 4C00h
        int 21h
end start