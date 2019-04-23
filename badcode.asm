section code vstart=0x200000

[bits 32]


mov edi,esi	;command line
cld

find:
lodsb
test al,al
jz gotid	;ebx whatever number

cmp al,0x20
jnz find
;esi -> argu

xor ebx,ebx	;result

getid:
lodsb
test al,0x40
ja .A	;letter

sub al,'0'
js gotid	;not number
cmp al,9
ja gotid	;not number

.N:	;translate hex
shl ebx,4
or bl,al
jmp getid

.A:
and al,0x1F	;toupper
dec al
js gotid	;'@' or '`'
cmp al,5
ja gotid	;not ABCDEF
add al,0x0A
jmp .N	;translate hex

gotid:
push edi
xor edx,edx
call (5*8):0x0	;print

jmp [sw+4*ebx]	;switch base on ebx

align 16

sw:
dd range
dd pagefault
dd segfault
dd idt
dd gate
dd ud
dd gatehack_1
dd gatehack_2


range:	;read kernel space
rdtsc
and eax,0x200000-1
mov edx,[eax]
jmp gotid


pagefault:	;access memory gap
xor eax,eax
dec eax
mov edx,[eax]
jmp gotid



segfault:	;load invalid segment
rdtsc
movzx edx,ax
cmp ax,0x28
jz segfault
push edx
push gotid
retf


idt:	;call interrupt
int 0x21
jmp gotid


gate:	;call invalid gate
call (0x10<<3):0x0

jmp gotid

ud:		;undefined instruction
ud2
jmp gotid


gatehack_1:	;let kernel access memory gap
xor eax,eax
dec eax
xor ax,ax
push eax	;0xFFFF0000
xor edx,edx
call (5*8):0x0	;print
jmp gotid


gatehack_2:	;let kernel use invalid segment

xor eax,eax
mov edx,5
push eax
mov cx,0x10
mov ds,cx
mov es,cx

call (5*8):0x0
mov cx,(4<<3); | 0011_b
mov es,cx
mov ds,cx

jmp gotid

