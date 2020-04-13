.model small
.stack 100h

.data
                  
ms_size equ 30
row_size equ 5

ms dw ms_size dup(0)
sum_per_column dw row_size dup(0)

enter_num_start  db "ms[$"
enter_num_finish db "]: $"
lowest_sum_message db "Columns with the lowest sum: $"
buff    db 6,7 Dup(?)
error db "Incorrect number, try again: $"

.code


new_line macro
    mov dl,10
    mov ah,2
    int 21h
    mov dl,13
    mov ah,2
    int 21h
endm

output proc
  ; Check a sign.
   test    ax, ax ; cf - negative flag
   jns     loop1

    
   ; Print '-' if negative
   mov  cx, ax
   mov     ah, 02h
   mov     dl, '-'
   int     21h
   mov  ax, cx
   neg     ax ; make it positive 
    ; cx - digit count
loop1:  
    xor     cx, cx
    mov     bx, 10 ; system base
loop2:
    xor     dx,dx
    div     bx  ; divide by numeral system base

    push    dx
    inc     cx 

    test    ax, ax
    jnz     loop2

    mov     ah, 02h
loop3:
    pop     dx
    add     dl, '0'
    int     21h
    loop    loop3
    ret
output endp

input proc
    start_input: 
    mov ah,0ah
    
    xor di,di
    mov dx,offset buff ;
    int 21h
	
    mov dl, 0dh
    mov ah,02
    int 21h
    mov dl,0ah
    int 21h
    
    mov si,offset buff+2 
    cmp byte ptr [si],"-" ; if negative set a flag in di
    jnz @loop1
    mov di,1   
    inc si    
@loop1:
    xor ax,ax
    mov bx,10 
@loop2:
    mov cl,[si]
    cmp cl,0dh  ; check for the end
    jz endin
    
	; validation
    cmp cl,'0' 
    jb er
    cmp cl,'9'
    ja er
 
    sub cl,'0'  
    mul bx  
    add ax,cx 
    inc si 
    jmp @loop2 
 
er: 
    mov dx, offset error
    mov ah, 09
    int 21h
    jmp start_input
 

endin:
    cmp di,1 ; 1 - the number is negative
    jnz @loop3
    neg ax  
@loop3:
    ret

input endp
 
output_matrix proc
    xor cx,cx
    xor si,si
    xor dx, dx 
    print:
        xor ax,ax
        mov ax, ms[si]
        push dx
        push si
        push cx
        call output
        mov dl, ' '
        int 21h
        pop cx
        pop si
        pop dx
        
        inc cx
        inc dx 
        
        cmp dx, row_size
        jl @skip
        new_line
        xor dx, dx
        
        
         
        @skip:
        add si, 2
        
        cmp cx, ms_size
        jl print
    ret     
output_matrix endp 
     
fill_matrix proc
    mov cx, 0
    xor di, di
    xor si, si   
    fill:
        
        
        push bx
        push cx
        push dx
        push si
        push di
        
        mov ah, 9
        lea dx, enter_num_start
        int 21h
        
        mov ax, cx
        call output
        
        mov ah, 9
        lea dx, enter_num_finish
        int 21h
        
        xor ax, ax
        call input
        
        pop di
        pop si
        pop dx
        pop cx
        pop bx   
        
        ; add input to ms
        mov ms[si], ax
        cmp cx, row_size 
        jl skip
        ; check for a new col
        mov ax, row_size*2
        cmp di, ax
        je null
        jmp skip
    null:
        xor di, di
    skip:
        mov ax, ms[si]
        add ax, sum_per_column[di]  
        mov sum_per_column[di], ax       
        
        add si, 2
        add di, 2
                
        inc cx
        cmp cx, ms_size
        
        jl fill
    ret  
fill_matrix endp     

print_min_column_index proc
    xor si, si
    xor cx, cx
    mov ah, 9
    lea dx, lowest_sum_message
    int 21h
    xor dx, dx
    
    mov ax, sum_per_column[si]
    add si, 2
    inc cx
    find_min:
        mov bx, sum_per_column[si]
        cmp ax, bx
        jg less
        jmp next
    less:
        mov ax, sum_per_column[si]
    next:
        add si, 2
        inc cx
        cmp cx, row_size
        je print_min
        jmp find_min
    print_min:
		xor cx, cx
		xor si, si
		check_each:
			mov bx, sum_per_column[si]
			cmp ax, bx
			je @print
			jmp @next
			@print:
			    push ax
				mov ax, cx
				inc ax
				push cx
				call output
				mov dx, ' '
				int 21h 
				pop cx
				pop ax
			@next:
				add si, 2
				inc cx
				cmp cx, row_size
				jne check_each
    ret           
print_min_column_index endp
  
            
; main
start proc near
	; Aaanoe iao?eoo oaeuo ?enae ?acia?iinou? 5x6 yeaiaioia. 
	; Iaeoe iiia?a noieaoia n ieieiaeuiie noiiie yeaiaioia
	mov ax, @data
	mov ds, ax 
    xor cx, cx
    xor si, si
    call fill_matrix
    call output_matrix
    call print_min_column_index
    mov ax, 4c00h
    int 21h
start endp
end start