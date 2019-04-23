section code vstart=0x200000

[bits 32]



mov ebx,esi	;command line
cld

find:
lodsb
test al,al
jz hint	;no argu show hint

cmp al,0x20
jnz find

;esi -> argu
mov edi,esi
xor edx,edx	;result

getid:
lodsb
test al,0x40
ja .A	;letter

sub al,'0'
js kill		;not number
cmp al,9
ja kill		;not number

.N:		;translate hex
shl edx,4
or dl,al
jmp getid

.A:
and al,0x1F	;toupper
dec al
js kill		;'@' or '`'
cmp al,5
ja kill		;not ABCDEF
add al,0x0A
jmp .N	;translate hex


fail:
mov eax,'fail'
stosd
xor eax,eax
stosd
jmp print

hint:
mov ebx,strhint
jmp print

kill:
push edx	;target ID
mov edx,7
call (5*8):0x0	;kill

test eax,eax
jz fail

print:
push ebx
xor edx,edx
call (5*8):0x0	;print

push edx	;0
mov edx,7
call (5*8):0x0	;kill self
int3	;never goes here

strhint db 'KILL [hexid]',0

