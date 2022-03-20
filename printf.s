
global printf

section .data
Buffer db 2048 dup (0)

section .text

    ;; Macro to define which register use for printf. It depend from % number
%macro UseReg 1
.%1:
  mov rax, %1
  ret
%endm

    ;;  Checking for flush buffer, argument is register used as a temp. 
    ;   First arg - offset from buffer size
    
%macro .CheckFlush 1

    cmp rbx, BufferEndIndx - %1    
    jl .NoFlush
    call FlushBuffer
.NoFlush:

%endm

%macro .BuffMov 0 
    mov al, byte [rdi]
    mov byte [rbx], al
%endm

%macro .DoReverse 0

.Reverse:
    mov r11b, byte [rbx]
    mov r10b, byte [r12]

    mov byte [r12], r11b
    mov byte [rbx], r10b

    sub rbx, 1
    add r12, 1

    cmp rbx, r12
    ja .Reverse

%endm

StackPrologSize equ 16

BufferSize      equ 2048
MaxItoaSize     equ 64
BufferEndIndx   equ Buffer + BufferSize - 1
RegArgMax       equ 4                 ; Start counting from zero


;NOTE:::::::::::::::::::::::::::::::::::::::::::::
; A assembly-like printf from standard c library
; All parametres used in this procedure should be in stack
; This is complies with the fastcall standart
; For fisrt 6 parameteres you have to use NOTE: RDI, RSI, RDX, RCX, R8, R9
; For other parameteres use stack
; RDI = format string
; Destr: RAX, RDX, R15, RSI, RDI

printf:
    lea rbx, Buffer
    xor r14, r14                ; For correct work

.FindSpec:
    cmp byte [rdi], 0
    je .WriteStr

    .BuffMov

    cmp byte [rdi], '%'         ; Specifier begin
    je .HandleSpec

    add rbx, 1                  ; Go further
    add rdi, 1


    .CheckFlush 0
    jmp .FindSpec

.HandleSpec:
   
    call CmpSpecifier
    jmp .FindSpec

.WriteStr:

    call FlushBuffer

    ret


; NOTE::::::::::::::::::::::::::::::::::::::::::::
; Entry: RSI - address of symbol to check to printf specifier
;        RBP - argument number
; If symbol is printf specifier will handle the argument
; Destr: RDI, RSI, R10, RBP, RAX
;

CmpSpecifier:

    add rdi, 1              ; Get a specifier that stayed by one

.DefineSpec:
    xor rax, rax                 ; For correct work
    mov al, byte [rdi]         ; Get specifier from buffer

    mov rax, qword [8*rax + SpecJmpTable]
    jmp rax


; Specifier jump table including cases %b, %c, %d, %x, %o, %s, TODO: %%
; section .data
SpecJmpTable:
   times '%' -  0      dq  Exit     ; cases from /000 to '$'
                       dq  .PercSpec     ; case '%'
   times 'b' - '%' - 1 dq  Exit     ; case from '$' to 'a'
                       dq .ByteSpec          ; case 'b' - binary number
                       dq .CharSpec          ; case 'c'
                       dq .DecSpec           ; case 'd'
   times 'o' - 'd' - 1 dq  Exit     ; Cases 'e'-'n'
                       dq .OctSpec          ; case 'o' - octal number
   times 's' - 'o' - 1 dq  Exit
                       dq .StrSpec          ; case 's' - string to output
   times 'x' - 's' - 1 dq  Exit
                       dq .HexSpec          ; case 'x' - hexidecimal number
   times 255 - 'x' - 1 dq  Exit                   ; All other cases


.ByteSpec:
    mov r13, 1
                                 ; radix = 2^(cl) -> cl = 1. See The itoa2pow doc
    call .RegDefine

    jmp .Handle2pow              ; Handle integer argument

.CharSpec:
    call .RegDefine

    mov byte [rbx], al
    add rbx, 1

    jmp Exit.HandledSpec

.PercSpec:
    add rdi, 1
    jmp Exit

.StrSpec:
    call .RegDefine

    call CpyStrArg

    jmp Exit.HandledSpec

.OctSpec:
    mov r13, 3
    call .RegDefine
    jmp .Handle2pow

.DecSpec:
    call .RegDefine
    call itoa10
    jmp Exit.HandledSpec

.HexSpec:
    mov r13, 4
    call .RegDefine

.Handle2pow:
    call itoa2pow

    jmp Exit.HandledSpec

.RegDefine:
    cmp r14, RegArgMax          ; First 6 parameter should be transferred by registers
                                ; The order of transferring: NOTE: RSI, RDX, RCX, R8, R9, <Stack>
    ja UseStack

    mov rax, qword [r14*8 + RegJmpTable]
    jmp rax

RegJmpTable   dq .RSI
              dq .RDX
              dq .RCX
              dq .R8
              dq .R9

    UseReg RSI                   ; macro used to save value to rax from corresponding register
    UseReg RDX
    UseReg RCX
    UseReg R8
    UseReg R9

UseStack:
    mov rax, r14

    sub rax, RegArgMax + 1                    ; Get from the stack the correct value

    mov rax, [rsp + StackPrologSize + rax*8]  ;
    ret

Exit:
    .CheckFlush 0
    add rbx, 1
    ret

.HandledSpec:
    add r14, 1
    add rdi, 1
    ret

;NOTE:::::::::::::::::::::::::::::::::::::::::::::
; Copy string from [RAX] to [RBX]
; Entry: RAX - address of string to copy
;        RBX - destination string (Buffer)

CpyStrArg:

.Cpy:
    cmp byte [rax], 0
    je .Exit

    .CheckFlush 0

    mov r11b, byte [rax]
    mov byte [rbx], r11b


    add rbx, 1
    add rax, 1

    jmp .Cpy

.Exit:
    ret

;NOTE:::::::::::::::::::::::::::::::::::::::::::::
; Convert number to ASCII symbol in decimal radix
; ENTRY: RAX - number to convert
;        RBX - destination buffer
; DESTR: r11, RBP, R11, RAX, RCX

itoa10:
    .CheckFlush MaxItoaSize

    xor r10, r10
    mov r10w, 10

    mov r11, rdx
    mov r12, rbx

    mov rdx, rax
    shr rdx, 32


.UseDecimalNumber:
    div r10d
    add dl, '0'

    mov byte [rbx], dl
    add rbx, 1

    xor rdx, rdx
    cmp eax, 0
    jne .UseDecimalNumber
                               ;
    mov rdx, r11

    mov rax, rbx
    sub rbx, 1

    .DoReverse
    mov rbx, rax

    ret


;NOTE:::::::::::::::::::::::::::::::::::::::::::::
; Convert integer number to string with terminate symbol '\0'
; Can be used only for a number system that is a multiple of a power of two
; Entry: RBX  - destination buffer to write number
;        RAX  - number to convert
;        R13b - power of two
; Destr: R10, R11, RBX, R12, R13b
; Ret:

itoa2pow:

    .CheckFlush MaxItoaSize
    
    xchg r13b, cl
    mov r12, rbx

    mov r10, 1
    shl r10, cl
    sub r10, 1

    cmp cl, 4
    jae .UseLettersNum          ; Only needed for 16, and 32 radix system
                                ; To indicate next numbers use letters
.UseDecimalNum:
    mov r11, rax
    and r11, r10                ; VAR % DIV = VAR & (DIV - 1), if DIV == power of two

    add r11b, '0'                 ; Convertation to decimal number
                                ;
    mov byte [rbx], r11b
    add rbx, 1

    shr rax, cl
    cmp rax, 0

    jne .UseDecimalNum

    jmp .ItoaExit

.UseLettersNum:
    mov r11, rax                ; VAR % DIV = VAR & (DIV - 1), if DIV == power of two
    and r11, r10

    cmp r11b, 9
    jbe .DecimalNum             ; Use Decimal Number

    sub r11b, 10                 ; Use Letters
    add r11b, 'A'

    jmp .WriteSym

.DecimalNum:
    add r11b, '0'

.WriteSym:
    mov byte [rbx], r11b         ; Save symbol to rdi
    add rbx, 1

    shr rax, cl                 ; DIV rax to radix
    cmp rax, 0
    jne .UseLettersNum

.ItoaExit:

    mov rax, rbx
    sub rbx, 1

    .DoReverse

    mov rbx, rax
    xchg r13b, cl
    ret

;NOTE:::::::::::::::::::::::::::::::::::::::::::::
; Output <Buffer> to stdout
; Entry: RDI - offset in <Buffer> - this is variable used to save string in printf function

FlushBuffer:
    mov r10, rdx                ; Save rdx
    mov r13, rsi                ; Save rsi
    mov r12, rdi                ; Save rdi

    lea rsi, Buffer             ; Find the length of buffer to output
    sub rbx, rsi                ;
    mov rdx, rbx                ;
    add rdx, 1

    mov rbx, rcx                ; Save rcx

    mov rdi, 1
    mov rax, 1

    syscall

    mov rdi, r12
    mov rsi, r13
    mov r10, rdx
    mov rcx, rbx

    lea rbx, Buffer

    ret
