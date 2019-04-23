section code vstart=0x200000

[bits 32]

mov esi,code
mov edi,eof
cld

print:
mov ebx,esi	;cur line
xor edx,edx

find:
lodsb
cmp al,9	;TAB
jz .sp

cmp al,0x0D	;CR
jnz .nsp

.sp:
mov BYTE [esi-1],0x20	;space

.nsp:
cmp al,0x0A	;LF
jnz find

;found line
mov [esi-1],dl	;0

push ebx
call (5*8):0x0	;print

;tsc as random number
rdtsc
movzx ecx,ax	;up to 65535
push ecx
mov edx,5
call (5*8):0x0	;sleep

cmp esi,edi
jb print

;no more text
xor eax,eax
push eax
mov edx,7
call (5*8):0x0	;kill self
int3	;never goes here

align 16

code:
incbin 'TSS.asm'
eof:



