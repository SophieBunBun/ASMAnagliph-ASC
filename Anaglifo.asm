EXTERN terminate
EXTERN printStr
EXTERN printStrLn
EXTERN readImageFile
EXTERN writeImageFile

section .data

    ;Error messages
    errMsgInvClr        db "Erro, modos de cor são M - Mono, C - Cor", 10, 0
    errMsgWrgArgC       db "Erro, são necessitados 4 argumentos, o modo de cor, os dois esteriogramas e o nome do anaglifo", 10, 0

SECTION .bss

    ;Right image storage
    img_rig_directory: resq 1
    img_rig_storage: resd 1048576
    img_rig_count: resq 1
    
    ;Left image storage
    img_lef_directory: resq 1
    img_lef_storage: resd 1048576
    img_lef_count: resq 1
    
    ;Final image storage
    final_img: resq 1048576
    final_img_name: resq 1

SECTION .text

global _start
_start:

;Checking if there are 5 arguments in total

    pop rax
    cmp rax,5
    je _validArgumentCount
    call errorWrongArgCount

;If agument count is valid, proceed.
_validArgumentCount:

    pop rax
    
    ;Saving arguments
    pop rdx
    pop qword [img_lef_directory]
    pop qword [img_rig_directory]
    pop qword [final_img_name]
    push rdx

    ;Reading right image file
    mov rdi,[img_rig_directory]
    mov rsi,img_rig_storage
    call readImageFile
    mov [img_rig_count],rax

    ;Reading left image file
    mov rdi,[img_lef_directory]
    mov rsi,img_lef_storage
    call readImageFile
    mov [img_lef_count],rax

    ;Writting image header
    mov rdi,final_img
    mov rsi,img_lef_storage
    call writeImageHeader

    ;Loading color options
    pop rdx
    cmp byte [rdx],'C'
    je _colorWrite
    cmp byte [rdx],'M'
    je _monoWrite
    call errorInvalidColorOption

    ;Writting COLOR anagliph to buffer
    _colorWrite:
    mov rdi,final_img
    mov rsi,[img_lef_count]
    mov rdx,img_lef_storage
    mov rcx,img_rig_storage
    call writeToImageBufferCOLOR
    jmp _writeToDisc

    ;Writting MONO anagliph to buffer
    _monoWrite:
    mov rdi,final_img
    mov rsi,[img_lef_count]
    mov rdx,img_lef_storage
    mov rcx,img_rig_storage
    call writeToImageBufferMONO
    jmp _writeToDisc

    ;Writting image to disc
    _writeToDisc:
    mov rdi,[final_img_name]
    mov rsi,final_img
    mov rdx,[img_lef_count]
    call writeImageFile

    ;Closing program
    call terminate

;--------------------------------------------------------------------
;Functions
;--------------------------------------------------------------------

;--------------------------------------------------------------------
; writeImageHeader
; Objective: Load image header from an existing bmp file to a storage buffer
; Input : 
;   RDI - Buffer adress to write to
;   RSI - Existing file to extract the header from
; Output: nothing
;--------------------------------------------------------------------
writeImageHeader:
    push rax
    push rbx
    push rcx
    
    xor rax,rax
    xor rbx,rbx
    xor rcx,rcx
    
    mov eax,[rsi + 10]
    ImgHeadFor:
    cmp rcx,rax
    jl ImgHeadLoop
    jmp ImgHeadClose
    ImgHeadLoop:
    mov bl,[rsi + rcx]
    mov [rdi + rcx],bl
    inc rcx
    jmp ImgHeadFor
    ImgHeadClose:
    pop rcx
    pop rbx
    pop rax
ret

;--------------------------------------------------------------------
; writeToImageBufferCOLOR
; Objective: Write anagliph data into storage buffer from two color pictures.
; Input : 
;   RDI - Buffer adress to write to (Assuming header has been written to buffer)
;   RSI - Image size
;   RDX - Picture left
;   RCX - Picture right
; Output: nothing
;--------------------------------------------------------------------
writeToImageBufferCOLOR:
    push rax
    push rbx
    
    xor rax,rax
    xor rbx,rbx
    
    mov eax,[rdi + 10]
    ImgBufCLRFor:
    cmp rax,rsi
    jl ImgBufCLRLoop
    jmp ImgBufCLRClose
    ImgBufCLRLoop:
    mov bl,[rcx + rax]
    mov byte [rdi + rax],bl
    mov bl,[rcx + rax + 1]
    mov byte [rdi + rax + 1],bl
    mov bl,[rdx + rax + 2]
    mov byte [rdi + rax + 2],bl
    mov byte [rdi + rax + 3],0xFF
    add rax,4
    jmp ImgBufCLRFor
    ImgBufCLRClose:
    pop rbx
    pop rax
ret

;--------------------------------------------------------------------
; writeToImageBufferMONO
; Objective: Write anagliph data into storage buffer from two mono-tone pictures.
; Input : 
;   RDI - Buffer adress to write to (Assuming header has been written to buffer)
;   RSI - Image size
;   RDX - Picture left
;   RCX - Picture right
; Output: nothing
;--------------------------------------------------------------------
writeToImageBufferMONO:
    push rax
    push rbx
    
    mov rbp,rsp
    sub rsp,16
    
    mov [rbp - 8],rdx
    mov [rbp - 16],rcx
    
    xor rax,rax
    xor rbx,rbx
    xor rcx,rcx
    xor rdx,rdx
    
    mov ecx,[rdi + 10]
    ImgBufMONOFor:
    cmp rcx,rsi
    jl ImgBufMONOLoop
    jmp ImgBufMONOClose
    ImgBufMONOLoop:
    push rdi
    mov rdi,[rbp - 16]
    lea rdi,[rdi + rcx]
    call ImgMONOGetColor
    pop rdi
    mov byte [rdi + rcx],al
    
    push rdi
    mov rdi,[rbp - 16]
    lea rdi,[rdi + rcx]
    call ImgMONOGetColor
    pop rdi
    mov byte [rdi + rcx + 1],al
    
    push rdi
    mov rdi,[rbp - 8]
    lea rdi,[rdi + rcx]
    call ImgMONOGetColor
    pop rdi
    mov byte [rdi + rcx + 2],al
    
    mov byte [rdi + rcx + 3],0xFF
    add rcx,4
    jmp ImgBufMONOFor
    ImgBufMONOClose:
    mov rsp,rbp
    pop rbx
    pop rax
ret

;--------------------------------------------------------------------
; ImgMONOGetColor
; Objective: Auxilary function to writeToImageBufferMONO, extracts color
;   using the mono algorithm from a picture.
; Input : 
;   RDI - Picture adress to sample color from
; Output:
;   RAX - Output color
;--------------------------------------------------------------------
ImgMONOGetColor:
    push rbx
    push rcx
    push rdx
    
    xor rbx,rbx
    xor rdx,rdx
    
    xor rax,rax
    mov al,[rdi]
    mov rdx,299
    mul rdx
    add rbx,rax
    
    xor rax,rax
    mov al,[rdi + 1]
    mov rdx,587
    mul rdx
    add rbx,rax
    
    xor rax,rax
    mov al,[rdi + 2]
    mov rdx,144
    mul rdx
    add rbx,rax
    
    mov eax,ebx
    xor edx,edx
    mov ebx,1000
    div ebx
    
    pop rdx
    pop rcx
    pop rbx

ret

errorInvalidColorOption:
    mov rdi,errMsgInvClr
    call printStrLn
    call terminate
    
errorWrongArgCount:
    mov rdi,errMsgWrgArgC
    call printStrLn
    call terminate