section code vstart=0x200000

[bits 32]

mov edi,esi
cld
xor ecx,ecx

;skip self name
find:
lodsb
cmp al,cl
jnz find

xchg esi,edi
mov BYTE [edi-1],0x20	;change terminator to space
mov ax,'0x'
stosw
;'COUNT 0x'

push eax
mov edx,3
call (5*8):0x0	;count

mov edx,eax
mov ebx,tab	;translation table
mov ecx,4	;4 char => 2 bytes

hex2str:
mov al,dh
shr al,4	;high 4 bit
xlatb
stosb
shl dx,4	;next 4 bit
loop hex2str

xor eax,eax
stosd	;terminate string
push esi
xor edx,edx
call (5*8):0x0	;print

push edx
mov edx,7
call (5*8):0x0	;kill self
int3	;never goes here



align 16
tab:
db '0123456789ABCDEF'
