section code vstart=0x200000

[bits 32]

mov edi,buf		;user input buffer
mov ebx,tab		;scancode translation
cld


getargu:
lodsb
test al,0xDF
jnz getargu
;esi argu of command line
xor edx,edx
push esi
call (5*8):0x0	;print


;esi as modify flag
;needs re-print when esi is not 0
msgloop:
xor edx,edx
push edx
inc edx
call (5*8):0x0	;scan
xor ecx,ecx
cmp eax,ecx
jz print	;no more code

cmp al,0xF0
jnz msgloop	;only translate keys at falling edge (aka when release a key)

push ecx
call (5*8):0x0	;scan again

test al,0x80
jnz msgloop	;not char keys

xlatb

;al ASCII
test al,al
jz msgloop	;not char

cmp al,0x0A		;Enter
jz exec
cmp al,0x08		;backspace
jnz .nbc

cmp edi,buf
jbe msgloop	;no char in buf

;erase last char
xor eax,eax
dec edi
mov [edi],eax
inc esi	;modified
jmp msgloop

.nbc:
cmp edi,strshell+80
jae print	;buf overflow

stosb	;put char to buf
inc esi	;modified
jmp msgloop

print:
xor eax,eax
cmp esi,eax
jz sleep	;not modified

mov ecx,strshell	;print together with 'Shell > '
mov [edi],al
push ecx
mov edx,eax		;0
call (5*8):0x0	;print

sleep:
push edx	;0
mov edx,5
call (5*8):0x0	;sleep
xor esi,esi		;reset modify
jmp msgloop

exec:
mov eax,buf		;command
mov edx,6
push eax
call (5*8):0x0	;create

;clear buf
xor edx,edx
mov edi,buf
mov [edi],edx
inc esi	;modified
cmp eax,edx
jnz print

;exec failed
mov ecx,strfail
push ecx
call (5*8):0x0	;print

jmp sleep

strfail db 'cannot find file',0


align 16
tab:
incbin 'scancode2ascii.bin'

align 16

strshell db 'Shell > '
buf dd 0
