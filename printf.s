

global _start

section .data
IntArg  dq 8 dup (0)
CharArg db 0
Kris    db "Kris"

section .text

CaseCount equ 'x' - 'b' + 1     ; Last case is 'x', first is 'b'. Also we have one more
                                ; Case for default
FirstCase equ 'b'

_start:

    ;; mov rsi, Kris
    ;; mov rcx, 's'
    ;; mov rdi, 1
    ;; call CmpSpecifier

    lea rdi, Kris

    call printf

    mov rax, 60
    xor rdi, rdi

    syscall

;------------------------------------------------
; A assembly-like printf from standard c library
; All parametres used in this procedure should be in stack
; This is complies with the cdecl standart
; For fisrt 6 parameteres you have to use NOTE: RDI, RSI, RDX, RCX, R8, R9
; For other parameteres use stack
;
; RDI = format string

printf:

    mov r10, rdi
    sub rdi, 1                  ; To compense the add in jump

.FindSpec:
    add rdi, 1

    cmp byte [rdi], 0
    je .WriteStr

    cmp byte [rdi], '%'              ; Specifier begin
    jne .FindSpec

    call .WriteStr


    




.WriteStr:
    sub rdi, r10

    mov rdx, rdi
    mov rsi, r10
    mov rax, 1
    mov rdx, r10
    mov rdi, 1


    syscall

    ret



;-------------------------------------------------
; Entry: ECX - symbol to check to printf specifier
;        RDI - descriptor of file
;        R10 - argument number
;        RDX - integer-type argument if 'x', 'd', 'o' or char-type argument if 'c'
;        RSI - address of string to output if specifier is 's'
; If symbol is printf specifier will handle the argument
; Destr: RAX, RCX, R8, R10


CmpSpecifier:

    sub ecx, FirstCase                ; First case is 'b'
    mov eax, ecx
    sub ecx, CaseCount
    ja NoSpec

    mov ecx, eax

    mov rcx, qword [8*ecx + JmpTable]
    jmp rcx

JmpTable: dq .ByteSpec          ; case 'b' - binary number
          dq .CharSpec          ; case 'c'
          dq  NoSpec            ; case 'd'
          dq  NoSpec            ; ...  'e'
          dq  NoSpec            ;      'f'
          dq  NoSpec            ;      'g'
          dq  NoSpec            ;      'h'
          dq  NoSpec            ;      'i'
          dq  NoSpec            ;      'j'
          dq  NoSpec            ;      'k'
          dq  NoSpec            ;      'l'
          dq  NoSpec            ;
          dq  NoSpec            ;
          dq  .OctSpec          ; case 'o' - octal number
          dq  NoSpec            ; ...
          dq  NoSpec            ;
          dq  NoSpec            ;
          dq  .StrSpec          ; case 's' - string to output
          dq  NoSpec            ; ...
          dq  NoSpec            ;
          dq  NoSpec            ;
          dq  NoSpec            ;
          dq  .HexSpec          ; case 'x' - hexidecimal number


.ByteSpec:
    mov cl, 1
    jmp .HandleInt

.CharSpec:
    lea rsi, CharArg            ; Save dl to CharArg
    mov byte [rsi], dl          ; RDX - should contain a character
    mov rax, 1
    mov rdx, 1

    syscall                     ; Output char
    jmp NoSpec

.StrSpec:

    call strlen

    mov rax, 1                  ; RSI = address of string to output

    syscall

    jmp NoSpec

.OctSpec:
    mov cl, 3
    jmp .HandleInt

.HexSpec:
    mov cl, 4

.HandleInt:
    mov r8, rdi
    lea rdi, IntArg             ; Convert number from rax to IntArg
    mov rbx, rdx
    call itoa2pow

    mov rdi, r8                 ; Wrote this by standart write function
    mov rax, 1
    lea rsi, IntArg
    syscall

NoSpec:
    ret

;-------------------------------------------------
; Found length of string
; Entry: RSI = address of string that end up with '\0'
; Ret:   RDX - length
; Destr: RDX, R8

strlen:
  mov r8, rsi


.FindEnd:
  cmp byte [rsi], 0
  je .Exit

  add rsi, 1

  jmp .FindEnd

.Exit:
  sub rsi, r8
  mov rdx, rsi
  mov rsi, r8

  ret

;-------------------------------------------------
; Convert integer number to string with terminate symbol '\0'
; Can be used only for a number system that is a multiple of a power of two
; Entry: RDI - destination buffer to write number
;        RBX - number to convert
;        CL  - power of two
; Destr: RDX, RBX, RAX, RCX, RDI
; Ret:   RDX - Converted string length


itoa2pow:
    mov rdx, 1
    shl rdx, cl                 ; Get the radix value to get remainder of a division to radix
    sub rdx, 1

    push rdi

    cmp cl, 4
    jae .UseLettersNum          ; Only needed for 16, and 32 radix system
                                ; To indicate next numbers use letters

.UseDecimalNum:
    mov rax, rbx
    and rax, rdx

    add al, '0'                 ; Convertation to decimal number
                                ;
    stosb
    shr rbx, cl

    cmp rbx, 0
    jne .UseDecimalNum
    jmp .ItoaExit

.UseLettersNum:
    mov rax, rbx
    and rax, rdx

    cmp al, 9
    jbe .DecimalNum

    sub al, 10
    add al, 'A'
    jmp .WriteSym

.DecimalNum:
    add al, '0'

.WriteSym:
    stosb

    shr rbx, cl
    cmp rbx, 0
    jne .UseLettersNum

.ItoaExit:
    mov byte [rdi], 0            ; '\0' to end string

    mov rdx, rdi
    sub rdx, [rsp]              ; Get pushed element without pop

    sub rdi, 1
    pop rbx
.Reverse:

    mov ah, byte [rdi]
    mov ch, byte [rbx]
    mov byte [rbx], ah
    mov byte [rdi], ch
    sub rdi, 1
    add rbx, 1

    cmp rdi, rbx
    ja .Reverse

    ret
