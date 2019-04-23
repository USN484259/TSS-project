section code vstart=0x200000

[bits 32]

;tsc as random number
rdtsc
movzx ebx,al	;up to 255

hello:

push esi	;command line
xor edx,edx
call (5*8):0x0	;print

rdtsc
movzx ecx,ax	;up to 65535
push ecx
mov edx,5
call (5*8):0x0	;sleep

dec ebx
jns hello	;print self <ebx> times

;change name to 'gdbye '
mov ecx,'gdby'
mov ax,'e '
mov [esi],ecx
mov [esi+4],ax

xor edx,edx
push esi
call (5*8):0x0	;print

xor eax,eax
push eax
mov edx,7
call (5*8):0x0	;kill self
int3	;never goes here




