section code vstart=0x200000

[bits 32]

mov edi,esi	;command line
cld

find:
lodsb
test al,al
jz hint	;no argu show hint

cmp al,0x20
jnz find

;esi -> argu

xor ebx,ebx	;result

getid:
lodsb
test al,0x40
ja .A	;letter

sub al,'0'
js cnt	;not number
cmp al,9
ja cnt	;not number

.N:	;translate hex
shl ebx,4
or bl,al
jmp getid

.A:
and al,0x1F	;toupper
dec al
js cnt	;'@' or '`'
cmp al,5
ja cnt	;not ABCDEF
add al,0x0A
jmp .N	;translate hex

cnt:
mov ecx,ebx		;spin <ecx> times

spin:
dec ecx
pause
jnz spin

push edi
xor edx,edx
call (5*8):0x0	;print

jmp cnt

hint:
mov esi,strhint
xor edx,edx
push esi
call (5*8):0x0	;print

push edx
mov edx,7
call (5*8):0x0	;kill self
int3	;never goes here

strhint db 'SPIN [hexcnt]',0
