
TSS_LEN equ 128
TSS_SH equ 7


GDT_BASE equ 0x00008000
TSS_BASE equ 0x00100000
TSS_GDT_OFF equ 0x10
TSS_NEXT equ 0x06

MAP_BASE equ 0x00060000
MAP_LIM equ (0x1000*33)

MEMSCAN_BASE equ 0x4000
PHY_BITMAP_BASE equ 0x6000
PHY_BITMAP_LIM equ 0x1000
PHY_MEMORY_BASE equ 0x00200000

BUFFER_COMMON equ 0x1F0000
USER_BASE equ 0x200000
STK_COMMON equ USER_BASE
;STK_BASE equ 0x1FF000
USER_MAP_BASE equ 0x1FF000

VGA_BASE equ 0xB8000
VGA_WIDTH equ 80
VGA_HEIGHT equ 25
VGA_LIM equ (VGA_WIDTH*VGA_HEIGHT*2)

KEYBD_BUF equ 0x4000
KEYBD_LIM equ 0x10
KEYBD_MASK equ 0x0F

KRNL_CREATE equ 'NEWT'
KRNL_KILL equ 'DELT'

section code vstart=0x10000

[bits 16]

push cs
pop ds


xor ebx,ebx
mov es,bx
;	ds	->	cur code segment
;	es	->	flat address

mov ax,bx
mov di,PHY_BITMAP_BASE
mov cx,PHY_BITMAP_LIM/2
dec ax
cld
rep stosw		;mark all memory as unavailable

xor ax,ax
mov di,MEMSCAN_BASE
mov cx,0x800
rep stosw		;clear memscan area

mov di,MEMSCAN_BASE
mov ecx,ebx
mov eax,0x534D4150	;'SMAP'

memscan_loop:
mov edx,eax
mov cx,20
mov eax,0xE820
int 0x15			;BIOS memory detection
jc memscan_end
xor edx,edx
add di,32
cmp ebx,edx
jnz memscan_loop

;	QWORD		base
;	QWORD		length
;	DWORD		type
;	BYTE[12]	alignment



memscan_end:



mov ax,0x0200
xor bx,bx
mov dx,0x1900
int 0x10	;hide cursor


mov dx,0x92
in al,dx
or al,2
out dx,al	;A20 gate

xor ax,ax
inc ax
push ax
mov ax,tmpgdt_base
push ax
mov ax,tmpgdt_len
push ax
mov di,sp
lgdt [ss:di]

;	sp+0	WORD length-1
;	sp+2	DWORD linear base


cli


mov eax,cr0
or eax,1
mov cr0,eax
;	enable PE

jmp DWORD 0x0008:pe_entry	;sys cs

align 16

KEYBD_read dw 0
KEYBD_write dw 0


VGA_line dd 0
TSS_shell dd 0


TSS_limit dd 1
TSS_cnt dd 1

FAT_table dd 0
FAT_data dd 0
FAT_cluster dd 0

align 16

strhello db 'Hello',0x0A,0
strworld db 'World',0x0A,0
strabort db 'ABORTED',0
strshell db 'shell.bin foo bar',0

align 16
tmpgdt_base:
dq 0	;first empty entrance

dw 0xFFFF
dw 0
db 0	;base addr
db 1001_1010_b
db 1100_1111_b
db 0		;sys cs

dw 0xFFFF
dw 0
db 0
db 1001_0010_b
db 1100_1111_b
db 0		;sys ds

dw 0xFFFF
dw 0
db 0
db 1111_1010_b
db 1100_1111_b
db 0		;user cs

dw 0xFFFF
dw 0
db 0
db 1111_0010_b
db 1100_1111_b
db 0		;user ds

dq 0	;end of GDT

tmpgdt_len equ ($-tmpgdt_base-1)

struc TSS
.nest: resw 1
resw 1
.esp0: resd 1
.ss0: resw 1
resw 1
.esp1: resd 1
.ss1: resw 1
resw 1
.esp2: resd 1
.ss2: resw 1
resw 1
.cr3: resd 1
.eip: resd 1
.eflags: resd 1
.eax: resd 1
.ecx: resd 1
.edx: resd 1
.ebx: resd 1
.esp: resd 1
.ebp: resd 1
.esi: resd 1
.edi: resd 1

.es: resw 1
resw 1
.cs: resw 1
resw 1
.ss: resw 1
resw 1
.ds: resw 1
resw 1
.fs: resw 1
resw 1
.gs: resw 1
resw 1
.ldt:	resw 1
resw 2
.iobase: resw 1

.avl:	resb 24
;	DWORD avl as valid flag
;	avl == self index if valid

;TRICK : kernel at index 0
;	cmp avl,index	kernel included
;	cmp avl,0		kernel excluded

endstruc

IDT_COREGATE equ ( 0x00008500<<32 | ( (TSS_GDT_OFF<<3)<<16) )
;	TSS gate on exception

;%define IDT_MAKETRAP(a) ( ( ( (a & 0xFFFF0000) | 0x8F00 )<<32) | 0x00080000 | (a & 0xFFFF) )

align 16

IDT_BASE:
dq IDT_COREGATE
dq IDT_COREGATE
dq 0	;dq IDT_MAKEINT(ISRabort)
dq IDT_COREGATE

dq IDT_COREGATE
dq IDT_COREGATE
dq IDT_COREGATE
dq IDT_COREGATE

dq 0	;dq IDT_MAKEINT(ISRabort)
dq IDT_COREGATE
dq 0	;dq IDT_MAKEINT(ISRabort)
dq IDT_COREGATE

dq IDT_COREGATE
dq IDT_COREGATE
dq IDT_COREGATE
dq IDT_COREGATE

dq IDT_COREGATE
dq IDT_COREGATE
dq 0	;dq IDT_MAKEINT(ISRabort)
dq IDT_COREGATE

times 12 dq IDT_COREGATE

dq 0	;dq IDT_MAKEINT(ISRtimer)
dq 0	;dq IDT_MAKEINT(ISRkeybd)
times 2 dq 0	;times 2 dq IDT_MAKEINT(ISRdummy)

IDT_LEN equ ($-IDT_BASE-1)

align 16

hextab:
db '0123456789ABCDEF'


[bits 32]


;	calling convention :
;	eax ecx caller preserved
;	ebx edx esi edi callee preserved
;	usually edx as argument  esi as 'source'  edi as 'target'
;	eax return value




align 16

;make interrupt gate

idt_make:	;ebx ISR addr		edx index
push edi
mov eax,0x00080000
mov edi,IDT_BASE
mov ax,bx

mov [edi+8*edx],eax

mov eax,ebx
mov ax,0x8E00	;1000_1110
mov [edi+8*edx+4],eax

pop edi
ret

pe_entry:

;reload all segments
mov ax,0x10
mov ds,ax
mov es,ax
mov fs,ax
mov gs,ax
mov ss,ax
mov esp,0x10000
mov ebp,esp		;stack frame

call VGA_clear	;zero vedio buffer

mov esi,strhello
call VGA_print


;move GDT to higher address
mov edi,GDT_BASE
mov ecx,0x1000
call zeromemory

mov edi,GDT_BASE
mov esi,tmpgdt_base
mov ecx,tmpgdt_len+1
shr ecx,2
rep movsd

mov ecx,(0x1000-1)<<16
push GDT_BASE
push ecx
lgdt[esp+2]


jmp 0x0008:gdt_redirect

abort:
mov esi,strabort
call VGA_print
cli
.hlt:
hlt
jmp .hlt


zeromemory:		;edi target ecx size in byte
push edx
push edi
mov edx,ecx
and edx,011b

cld
shr ecx,2
xor eax,eax
rep stosd

mov ecx,edx
rep stosb

pop edi
pop edx
ret




VGA_clear:
push edi
push ecx

mov edi,VGA_BASE
mov ecx,VGA_LIM
call zeromemory

pop ecx
pop edi
ret


VGA_scroll:		;return current VGA_line
;note that the last line is always preserved for shell output

mov eax,[VGA_line]
cmp eax,(2*VGA_WIDTH*(VGA_HEIGHT-2))
jae .sh		;scroll the screen
add eax,(2*VGA_WIDTH)
mov [VGA_line],eax
ret

.sh:
push esi
push edi

mov esi,VGA_BASE+2*VGA_WIDTH
mov edi,VGA_BASE
mov ecx,(VGA_WIDTH*(VGA_HEIGHT-2))
cld
rep movsw	;move one line up

mov ecx,VGA_WIDTH
xor eax,eax
rep stosw	;clear the last line

mov eax,[VGA_line]

pop edi
pop esi

ret



VGA_print:	;esi string
push ebx
push edx
push esi

mov ebx,[VGA_line]
xor edx,edx
cld

.printloop:
lodsb
cmp al,0
jz .term
cmp al,0x0A
jz .cr

;cur cursor at VGA_BASE+VGA_line+2*edx

mov ah,0x0F		;white text
mov [VGA_BASE+ebx+edx*2],ax
inc edx

cmp edx,VGA_WIDTH
jb .printloop

.cr:
call VGA_scroll
mov ebx,eax		;VGA_line
xor edx,edx
jmp .printloop


.term:
dec edx
js .end
call VGA_scroll
.end:
pop esi
pop edx
pop ebx

ret


;install or uninstall a TSS desscriptor
TSS_descriptor:	;edx index
push ebx
push edx

mov eax,edx
mov ebx,TSS_BASE
shl eax,TSS_SH
;xor edx,edx
mov ecx,edx
add ebx,eax		;target TSS entry

add ecx,TSS_GDT_OFF
;ecx TSS descriptor in GDT

cmp [ebx+TSS.avl],edx	;also init kernel task
jnz .tssdes_clear	;never delete kernel

;install
mov eax,GDT_BASE
mov edx,ebx
shl ebx,16
shr edx,16
mov bx,TSS_LEN-1

xchg ebx,eax

mov [ebx+8*ecx],eax

;	dx HWORD of entry	ecx index in GDT	ebx GDT_BASE

xor eax,eax
mov ah,dh

shl eax,16

mov ah,1000_1001_b
mov al,dl

mov [ebx+8*ecx+4],eax
jmp .tssdes_end

;uninstall
.tssdes_clear:	;ecx index in GDT
xor eax,eax
mov ebx,GDT_BASE
mov [ebx+8*ecx],eax
mov [ebx+8*ecx+4],eax

.tssdes_end:
pop edx
pop ebx
ret



;allocate physical page according to BITMAP
phy_alloc:
push esi

mov ecx,PHY_BITMAP_LIM
mov esi,PHY_BITMAP_BASE
cld

;find a 0 bit
.pa_loop:
lodsb
mov ah,8
.pa_test:
shr al,1
jnc .pa_found
dec ah
jnz .pa_test

loop .pa_loop

;no available page
call abort
; TODO : return NULL and change every reference to phy_alloc to fail on NULL

.pa_found:
;set this bit to 1
mov cl,ah
mov al,0x80
dec cl
dec esi
shr al,cl
or [esi],al

;get actual physical address
mov cx,8
sub esi,PHY_BITMAP_BASE
sub cl,ah
shl esi,3
mov eax,PHY_MEMORY_BASE
or si,cx
shl esi,12

add eax,esi

pop esi
ret		;return page address


;free physical page according to BITMAP
phy_free:	;edx target
push edx
push ebx

sub edx,PHY_MEMORY_BASE
js abort	;not allocable memory
test edx,0x0FFF
jnz abort	;not aligned

shr edx,12
mov cl,dl
mov ebx,PHY_BITMAP_BASE
shr edx,3
and cl,0000_0111_b

cmp edx,PHY_BITMAP_LIM
jae abort	;out of range
add ebx,edx

mov dl,1
shl dl,cl

mov al,[ebx]
test al,dl
jz abort	;bit 0 is impossible

not dl

and [ebx],dl

pop ebx
pop edx
ret




;get current task ID
TSS_self:
xor eax,eax
str ax		;cur TR selector
shr eax,3
sub eax,TSS_GDT_OFF
js abort	;not a task ?
ret


;get TSS entry
TSS_get:	;inner function		edx index

push edx

cmp edx,[TSS_limit]
jae .fail

mov eax,TSS_LEN
mul edx
;assume edx 0 after mul
add eax,TSS_BASE

;eax entry
cmp [eax+TSS.avl],edx	;	0x0
jz .fail

jmp .end

.fail:
xor eax,eax

.end:
pop edx

ret

;get task count
TSS_count:
mov eax,[TSS_cnt]
ret

;enum all task
TSS_enum:	;edx cur id
push ebx
push edx

mov ebx,TSS_BASE
mov eax,TSS_LEN
;xor ecx,ecx
mul edx
add ebx,eax		;ebx current entry

mov edx,[esp]	;current id
.find:
inc edx
add ebx,TSS_LEN
cmp edx,[TSS_limit]
jb .nloop
;index loop back to 0
xor edx,edx
mov ebx,TSS_BASE
.nloop:
cmp edx,[ebx+TSS.avl]	;kernel task included
jnz .find
mov eax,edx		;return newindex

pop edx
pop ebx
ret


;create new task and load file to execute
TSS_new:	;esi command line		edx parent  aka 'which task called create'

;WARNING	could only be called on kernel task
call TSS_self
dec eax
jns abort	;not kernel task

call loadfile

push edx
push ebx
push esi
push edi
push ebp
mov ebp,esp

;	+00		old ebp
;	+04		edi
;	+08		esi
;	+0C		ebx
;	+10		edx


push eax	;first cluster of file


xor ecx,ecx
cmp eax,ecx
jz .endproxy	;short jmp out of range

mov edx,ecx		;0x0
mov ebx,TSS_BASE

.new_loop:

inc ecx
cmp ecx,[TSS_limit]
jae .new_expand

mov eax,ecx
shl eax,TSS_SH
mov eax,[ebx+eax+TSS.avl]
cmp eax,edx
jz .new_found
jmp .new_loop

.endproxy:
jmp .end

.new_expand:
;inc upper bound
mov eax,ecx
inc eax
mov [TSS_limit],eax

.new_found:	;ebx base ecx index

mov edx,ecx
shl ecx,TSS_SH
add ebx,ecx	;ebx TSS entry

mov edi,ebx
mov ecx,TSS_LEN
call zeromemory

;init TSS structure
mov ax,ss
mov ecx,STK_COMMON
mov [ebx+TSS.esp0],ecx
mov [ebx+TSS.ss0],ax
mov [ebx+TSS.esp1],ecx
mov [ebx+TSS.ss1],ax
mov [ebx+TSS.esp2],ecx
mov [ebx+TSS.ss2],ax

mov ax,(4<<3) | 0011_b	;user data
mov [ebx+TSS.ds],ax
mov [ebx+TSS.es],ax
mov [ebx+TSS.fs],ax
mov [ebx+TSS.gs],ax
mov [ebx+TSS.ss],ax

mov ax,(3<<3) | 0011_b	;user code
mov [ebx+TSS.cs],ax

mov DWORD [ebx+TSS.eflags],0000_0010_0000_0010_b	;IF set


mov eax,[ebp+0x10]	;parent index
mov [ebx+TSS.avl],edx	;index
mov [ebx+TSS.eax],eax

;phy page mapping
push ebx	;cur TSS entry

call phy_alloc
mov [ebx+TSS.cr3],eax
mov ebx,eax		;dir entry

mov edi,eax
mov ecx,0x1000
call zeromemory

call phy_alloc
mov edi,eax		;tab entry
mov al,0000_0111_b
mov [ebx],eax	;only 1 table in directory


mov esi,MAP_BASE+0x1000
mov ecx,(USER_MAP_BASE>>12)
cld
rep movsd	;map kernel space


call phy_alloc
mov al,0000_0011_b
stosd		;ring0 stack page

;	assert( ( (edi & 0x0FFF)/4 ) <<12 == USER_BASE )
mov ebx,USER_BASE
movzx eax,di
and ax,0x0FFF
shl eax,10
cmp eax,ebx
jnz abort



mov edx,[esp+4]		;first cluster
;edi next tab entry

.load:

call phy_alloc
mov ebx,eax
mov al,0000_0111_b
stosd

;edi	page table next record
;(edi & 0x0FFF) << 10		logical address

;ebx	cur phy addr

xchg ebx,edi

.loadloop:
;edi cur phy addr
;ebx next tab record

call readfile	;edx cur cluster	edi target auto inc

xor ecx,ecx
mov edx,eax
cmp eax,ecx
jz .brk		;no more cluster

test edi,0x0FFF
jnz .loadloop	;(4K / 512*SpC) times to fill a page

mov edi,ebx
jmp .load


.brk:	;ebx	page table next record
mov edi,ebx
movzx edx,bx
and dx,0x0FFF
shl edx,10		;cur vir addr


pop ebx		;cur TSS entry


call phy_alloc
mov ecx,eax
mov al,0000_0111_b
stosd		;extra page for stack and command line

mov esi,[ebp+8]		;command
mov edi,ecx		;extra page base
mov ecx,0x100	;256 char

.cpy:
lodsb
test al,al
stosb

loopnz .cpy		;strncpy
xor eax,eax
stosd	;ensure string is terminated

mov DWORD [ebx+TSS.esi],edx		;command line

add edx,0x1000

mov [ebx+TSS.esp],edx	;stack top
mov DWORD [ebx+TSS.eip],USER_BASE


mov edx,[ebx+TSS.avl]	;index

call TSS_descriptor		;install TSS descriptor

;TSS_cnt++
mov ecx,[TSS_cnt]
cmp ecx,[TSS_limit]
jae abort
inc ecx
mov [TSS_cnt],ecx


mov eax,edx		;return task ID


.end:

mov esp,ebp
pop ebp
pop edi
pop esi
pop ebx
pop edx
ret


TSS_delete:	;edx index

;WARNING	could only be called on kernel task
call TSS_self
dec eax
jns abort

push edx
push ebx
xor ecx,ecx
mov ebx,TSS_BASE
cmp edx,ecx
jz .fail
cmp edx,[TSS_limit]
jae .fail
mov eax,edx
shl eax,TSS_SH
add ebx,eax
;mov eax,edx
xchg ecx,[ebx+TSS.avl]
test ecx,ecx
jz .fail	;don't kill kernel task
cmp ecx,edx
jnz abort	;should be a vaild task

;TSS_cnt--
mov eax,[TSS_cnt]
dec eax
jz abort
mov [TSS_cnt],eax


;uninstall TSS descriptor
;edx index

call TSS_descriptor

;free space here
mov edx,[ebx+TSS.cr3]
mov ebx,[edx]	;page table
call phy_free	;free page directory
;TRICK : task operation only by kernel task so it's okay to hold 
;physical page that is already 'freed' until return
and bx,0xF000
mov ecx,(USER_MAP_BASE>>12)	;non-kernel page index

.delete_loop:
mov eax,[ebx+4*ecx]
test eax,eax
jz .delete_tab
mov edx,eax
and dx,0xF000

push ecx

call phy_free	;free user page

pop ecx

inc ecx

cmp ecx,(0x1000/4)
jb .delete_loop

.delete_tab:
mov edx,ebx
and dx,0xF000
call phy_free	;free page table

mov eax,[esp+4]		;return index
jmp .del_ret
.fail:
xor eax,eax

.del_ret:
pop ebx
pop edx
ret


;switch to another task
TSS_switch:
;assert(IF == 0)

call IF_assert

push ebx
push edx

call TSS_self
mov edx,eax
call TSS_enum
cmp eax,edx
jz .nsw		;no switch
;eax target task ID

mov ebx,GDT_BASE+8*TSS_NEXT
add eax,TSS_GDT_OFF
shl eax,(16+3)
mov [ebx],eax

mov DWORD [ebx+4],0x00008500
;make TSS gate pointing to target TSS

pop edx
pop ebx

jmp (TSS_NEXT<<3):0x0	;to TSS gate

ret

.nsw:

pop edx
pop ebx
ret


;interrupt should be disabled
IF_assert:

pushfd
pop eax
test ax,0x0200
jnz abort

ret

;ATA PIO mode LBA28
readsector:	;edx lba addr edi target
test edx,0xF0000000		;LBA28 limitation
jnz abort

push edi
push edx

mov al,1
mov dx,0x1F2
out dx,al	;1 sector

inc dx
mov eax,[esp]	;LBA addr
out dx,al

inc dx
shr eax,8
out dx,al

inc dx
shr eax,8
out dx,al

inc dx
shr eax,8
or al,0xE0
out dx,al	;set LBA addr & master drive LBA mode

inc dx
mov al,0x20
out dx,al	;read command

xor ecx,ecx
.wait:
inc ecx
jc abort	;timeout

in al,dx
test al,0x80
jnz .wait
test al,0010_0001_b
jnz abort	;device failure
test al,0x08
jz .wait

;device ready

mov dx,0x1F0
mov ecx,0x100	;256 times
cld
rep insw	;get data from ATA

pop edx
pop edi
ret

;read cluster to edi
;auto add edi (cluster size)
;return next cluster (0 for EOF)
readfile:	;edx cur cluster	ret next cluster	edi target auto inc

cmp edx,0x0FFFFFF8
jae abort
cmp edx,0
jz abort

;valid cluster index

push ebx
push edx

xor eax,eax
mov ecx,128		;128 per sector
xchg eax,edx
div ecx
add eax,[FAT_table]
push edx	;remainder
mov edx,eax
call readsector		;read FAT

pop ecx		;remainder
mov ebx,[edi+4*ecx]		;next cluster

mov ecx,[FAT_cluster]
mov eax,[esp]	;cur cluster
mul ecx
add eax,[FAT_data]

sub eax,ecx
sub eax,ecx

mov edx,eax		;sector of cur cluster

;ecx SpC
.clusterloop:
push ecx

call readsector
add edi,0x200	;auto inc
inc edx

pop ecx
loop .clusterloop

mov eax,ebx		;next cluster
cmp ebx,0x0FFFFFF8
jb .next
xor eax,eax		;EOF
.next:

pop edx
pop ebx

ret



loadfile:	;esi command	ret first cluster
push edx
push ebx
push esi
push edi
push ebp
mov ebp,esp

mov ecx,'bin '	;dafault extension
mov eax,0x20202020	;blank filled
push eax
push ecx
push eax
push eax

cld
mov edi,esp

mov ecx,8	;name length
.name:
lodsb

test al,0xDF
jz .extfin	;no ext use default

cmp al,'.'
jz .namefin	;got extension
dec cl
js .fail	;name too long
stosb
jmp .name

.namefin:
add edi,ecx	;move to ext position
;inc edi
mov cl,3	;ext length

mov eax,[esp+0x0C]
mov [esp+0x08],eax	;have ext clear default

.ext:
lodsb
test al,0xDF
jz .extfin	;ext ends
dec cl
js .fail	;ext too long
stosb
jmp .ext

.extfin:
;esp points to filename in FAT32 format

mov edx,[FAT_data]
mov edi,BUFFER_COMMON+0x1000
call readsector		;get root directory

.loop:
mov esi,esp
mov ebx,edi

cmp BYTE [edi],0
jz .fail	;no more files

mov cl,11

;match filename
.match:
lodsb
xor al,[edi]
test al,(~ 0x20)
jnz .next
inc edi
dec cl
jnz .match

;name matched
test BYTE [ebx+0x0B],0x10
jnz .next	;directory

;found file
mov ax,[ebx+0x14]
shl eax,16
mov ax,[ebx+0x1A]

;got first cluster
jmp .ret


.next:
mov edi,ebx
add edi,0x20	;next entrance
jmp .loop


.fail:
xor eax,eax

.ret:


mov esp,ebp
pop ebp
pop edi
pop esi
pop ebx
pop edx
ret



hex2str:	;edi target		dx hex		ecx charcount up to 4
push edx
push ebx
push edi

mov ebx,hextab
.put:
mov al,dh
shr al,4
xlatb
stosb
shl dx,4
loop .put


pop edi
pop ebx
pop edx
ret

;call gate target
OS_call:	;edx function number


pushfd
push ebp
mov ebp,esp
;	+10		argu
;	+0C		cs
;	+08		eip
;	+04		eflags
;	+00		ebp


;adjust selector here

mov ecx,[ebp+0x0C]	;cs
mov ax,ds
arpl ax,cx
jz .xplode	;bad ds

mov ax,es
arpl ax,cx
jz .xplode	;bad es


cmp edx,SYSCALL_NUM
jae .xplode	;bad index
cli
jmp [edx*4+.switch]	;to subfunction

.switch:
dd .print	;0
dd .scan	;1
dd .self	;2
dd .count	;3
dd .enum	;4
dd .sleep	;5
dd .create	;6
dd .kill	;7


SYSCALL_NUM equ (($-.switch)/4)

align 16

.xplode:
xor edx,edx
int3	;trigger TSS gate

jmp .end


.print:
push esi
push edi

mov esi,[ebp+0x10]	;string
mov edi,BUFFER_COMMON+6
cmp esi,USER_BASE
jb .print_end	;bad addr
mov ecx,4000
cld
.printcpy:	;strncpy
lodsb
test al,al
stosb
loopnz .printcpy
xor eax,eax
stosd	;ensure string terminated

mov esi,BUFFER_COMMON
mov edi,esi

;print task ID
call TSS_self
mov edx,eax
mov ecx,4
call hex2str
mov ax,': '
mov [esi+4],ax

cmp edx,[TSS_shell]
jnz .normalprint
;always put shell output to the last line

add esi,6	;ignore shell ID
mov ecx,VGA_WIDTH
mov edi,VGA_BASE+VGA_WIDTH*(VGA_HEIGHT-1)*2


.print_loop:
lodsb
mov ah,0x0F
cmp al,0
jz .print_brk
stosw
loop .print_loop

.print_brk:
xor ax,ax
rep stosw

jmp .print_end



.normalprint:

call VGA_print

.print_end:

xor edx,edx		;recover edx
pop edi
pop esi
jmp .end

.scan:	;get keyboard input

call TSS_self
mov [TSS_shell],eax		;register as shell

movzx edx,WORD [KEYBD_read]
xor ecx,ecx
cmp dx,[KEYBD_write]
jz .scanend		;queue empty	ecx as return

mov al,[KEYBD_BUF+edx]
inc dx
and dx,KEYBD_MASK	;queue loop back

cmp al,0xF0
jnz .scanpas
cmp dx,[KEYBD_write]
jz .scanend		;keep 0xF0 when there's no more

.scanpas:
movzx ecx,al	;ecx as return
mov [KEYBD_read],dx


.scanend:

mov eax,ecx

xor edx,edx
inc edx		;recover edx

jmp .end

.self:
call TSS_self
jmp .end

.count:
call TSS_count
jmp .end

.enum:
mov edx,[ebp+0x10]	;argu
call TSS_enum
mov edx,4	;recover edx

jmp .end

.sleep:

mov edx,[ebp+0x10]	;argu
.sleeploop:
call TSS_switch
dec edx
jns .sleeploop	;sleep (argu) times

mov edx,5	;recover edx	
jmp .end

.create:

push esi
push edi

xor eax,eax
mov esi,[ebp+0x10]	;command
mov edi,BUFFER_COMMON
cmp esi,USER_BASE
jb .creatend	;bad addr

mov ecx,0x100
cld

.createcpy:		;strncpy

lodsb
test al,al
stosb

loopnz .createcpy

xor eax,eax
stosd	;ensure string terminated

mov edx,KRNL_CREATE		;create tag
call (TSS_GDT_OFF<<3):0x0	;call kernel task

.creatend:

pop edi
pop esi
mov edx,6	;recover edx
jmp .end

.kill:

mov eax,[ebp+0x10]	;target ID
test eax,eax
jnz .killnself

;0 => kill self
call TSS_self

.killnself:
mov edx,KRNL_KILL	;kill tag
call (TSS_GDT_OFF<<3):0x0	;call kernel task

mov edx,7	;recover edx
jmp .end


.end:

mov esp,ebp
pop ebp
popfd

retf 4	;stdcall 1 argu


ISRtimer:
;interrupt shall preserve all registers
push eax
push ecx

mov al,0x20
out 0x20,al		;EOT


;IF checked in TSS_switch
;call IF_assert

call TSS_switch

;breakpoint here
;kernel task may resume from here because of TSS gate call
;shall preserve NT flag in such case

call TSS_self
test eax,eax
jz .krnlret		;if this is kernel task
pop ecx
pop eax
iret

.krnlret:

pop ecx
pop eax

;eflags
;cs
;ip

;shall preserve NT flag in eflags
;erase cs and eflags on stack

retn 8



ISRkeybd:
pushad	;interrupt preserve all regs


mov al,0x20
out 0x20,al	;EOT

;interrupt gate should have disabled interrupt
call IF_assert

in al,0x60	;scancode from keybd


;put into queue
movzx edx,WORD [KEYBD_write]
mov ecx,edx
inc dx
mov [KEYBD_BUF+ecx],al
and dx,KEYBD_MASK
cmp dx,[KEYBD_read]
jz .skip	;queue full
mov [KEYBD_write],dx

.skip:

popad
iret



ISRdummyarg:	;exception with errorcode
add esp,4
ISRdummy:	;exception without errorcode
iret	;just return

ISRabortarg:	;with errorcode
add esp,4
ISRabort:		;jmp to abort
mov DWORD [esp],abort
iret


gdt_redirect:
add esp,8	;2 pushes when redirecting



;register call gate at GDT 5
mov ebx,GDT_BASE
mov ax,cs
shl eax,16

mov edx,OS_call
mov ax,dx

mov [ebx+8*5],eax

mov dx,1110_1100_000_00001_b

mov [ebx+8*5+4],edx


;	mapping init
mov edi,MAP_BASE
mov ecx,MAP_LIM
call zeromemory


mov edi,MAP_BASE
mov ecx,0x21	;page table count
mov eax,edi
mov cr3,edi
or ax,0000_0001_0000_0011_b
cld

mapinit_dir:
add eax,0x1000
stosd	;set page table addr
loop mapinit_dir

;memory gap at nullptr
xor eax,eax
mov edi,MAP_BASE+0x1000
stosd

mov ecx,0x400*0x21-1	;all memory linear mapping for kernel
mov ax,0000_0001_0000_0011_b

mapinit_loop:
add eax,0x1000
stosd
loop mapinit_loop


;enable paging
mov eax,cr0
or eax,0x80000000
mov cr0,eax

;init kernel TSS
mov ebx,TSS_BASE
mov eax,STK_COMMON
mov edx,MAP_BASE
mov cx,ss

mov [ebx+TSS.cr3],edx
mov [ebx+TSS.esp0],eax
mov [ebx+TSS.ss0],cx
mov [ebx+TSS.esp1],eax
mov [ebx+TSS.ss1],cx
mov [ebx+TSS.esp2],eax
mov [ebx+TSS.ss2],cx

mov dx,cs
mov [ebx+TSS.ds],cx
mov [ebx+TSS.es],cx
mov [ebx+TSS.fs],cx
mov [ebx+TSS.gs],cx
mov [ebx+TSS.ss],cx
mov [ebx+TSS.cs],dx

xor edx,edx

mov [ebx+TSS.avl],edx	;ID of kernel is 0

call TSS_descriptor		;install TSS descriptor

mov cx,(TSS_GDT_OFF << 3)
ltr cx	;register self as task



;build physical memory BITMAP
mov esi,MEMSCAN_BASE
mov edi,PHY_BITMAP_BASE

bitmap_loop:
mov eax,[esi+0x10]
xor edx,edx
dec eax
js bitmap_end	;no more entrance
jnz bitmap_next	;memory not available

cmp [esi+0x04],edx
jnz bitmap_next	;ignore memory above 4G

mov ebx,[esi]
mov eax,ebx

;align to 4KB
shr ebx,12
test eax,0x0FFF
jz bitmap_nalign
inc ebx
bitmap_nalign:

;ebx page index

mov edx,[esi+0x08]	;size
shr edx,12	;size in page

mov eax,(PHY_MEMORY_BASE>>12)
sub eax,ebx
js bitmap_match
;adjust base and size

sub edx,eax
js bitmap_next	;whole block below PHY_MEMORY_BASE
jz bitmap_next

;some above PHY_MEMORY_BASE
mov ebx,(PHY_MEMORY_BASE>>12)

bitmap_match:

sub ebx,(PHY_MEMORY_BASE>>12)

;ebx bit offset in BITMAP

bitmap_set:	;ebx base off	edx count
mov al,1
mov cl,bl
and cl,0000_0111_b
shl al,cl	;target bit

mov ecx,ebx
not al		;bit mask
shr ecx,3	;target byte
cmp ecx,PHY_BITMAP_LIM
jae bitmap_end	;out of range
and [edi+ecx],al	;clear the bit

inc ebx
dec edx
jnz bitmap_set

bitmap_next:
add esi,32	;next entrance
jmp bitmap_loop

bitmap_end:


mov edi,BUFFER_COMMON
mov ecx,USER_BASE-BUFFER_COMMON
call zeromemory		;clear buffer area

;read MBR
xor edx,edx
call readsector		;edi buffer

;FAT32 reconstruct

mov edx,[edi+0x1C6]
call readsector		;read FAT32 header

;FAT32 header shall equal to boot area
mov esi,0x7C00
mov ecx,0x80
cld
repz cmpsd
jnz abort

movzx eax,WORD [0x7C00+0x0E]	;reserved sectors

add edx,eax

mov [FAT_table],edx

mov eax,[0x7C00+0x24]	;sectors per FAT
shl eax,1
add edx,eax

mov [FAT_data],edx

movzx ecx,BYTE [0x7C00+0x0D]	;SpC
cmp cl,8
ja abort	;cluster over 4K not supported
mov [FAT_cluster],ecx

;IDT init

;fill blanks in IDT
xor edx,edx
mov ebx,ISRabort
mov dl,2
call idt_make
mov dl,0x12
call idt_make

mov ebx,ISRabortarg
mov dl,8
call idt_make
mov dl,0x0A
call idt_make

mov ebx,ISRtimer
mov dl,0x20
call idt_make
mov ebx,ISRkeybd
inc dl
call idt_make
mov ebx,ISRdummy
inc dl
call idt_make
inc dl
call idt_make

;register IDT
mov eax,IDT_BASE
mov edx,IDT_LEN<<16
push eax
push edx
lidt [esp+2]
add esp,8


;PIT init
mov al,0011_0100_b
out 0x43,al
nop

;0x2E9C * 0.8381us	-->		10ms
mov dx,0x40
mov al,0x9C
out dx,al
nop
mov al,0x2E
out dx,al

nop

;keyboard init
mov al,0x60
out 0x64,al
nop
mov al,0101_b
out 0x60,al

mov al,0xAE
out 0x64,al

mov al,0xFF
out 0x60,al

nop

;PIC init here

mov al,0x11
out 0x20,al
nop
out 0xA0,al
nop
mov al,0x20
out 0x21,al
nop
mov al,0x28
out 0xA1,al
nop
mov al,4
out 0x21,al
nop
mov al,2
out 0xA1,al
nop
mov al,1
out 0x21,al
nop
out 0xA1,al
nop
mov al,1111_1100_b
out 0x21,al





mov esi,strworld
call VGA_print

;load shell.bin
xor edx,edx
mov esi,strshell

call TSS_new

;switch to shell

xor ecx,ecx
mov edx,5	;sleep
push ecx
call (5*8):0x0

;go into kernel service

mov ebp,esp

krnlservice:
;interrupt shall be disabled for kernel
call IF_assert

pushfd
pop edx
test edx,0x4000		;NT bit
jnz .srv

;no NT	a halt request

sti
hlt		;wait for next interrrupt
cli
jmp krnlservice

.srv:	;NT	=>	kernel service call
movzx edx,WORD [TSS_BASE+TSS.nest]	;call from whom ?
test dx,0x07
jnz krnlservice	;bad selector
shr edx,3
sub dx,TSS_GDT_OFF
js krnlservice	;not from a task ?

;	edx caller ID
call TSS_get
test eax,eax
jz krnlservice	;invalid TSS
mov ebx,eax

;ebx TSS entrance
mov edx,[ebx+TSS.avl]	;caller ID
mov ecx,[ebx+TSS.eflags]
test ecx,0x0200		;IF bit
jnz .self	;IF set =>	task switch caused by exception	 kill caller task

mov eax,[ebx+TSS.edx]	;service tag
cmp eax,KRNL_CREATE
jnz .kil

;create
mov esi,BUFFER_COMMON	;command
;edx parent index
call TSS_new
mov [ebx+TSS.eax],eax

jmp .end



.self:
;edx caller ID
call TSS_delete
;caller task no longer exists	wait for timer to switch task

;clear NT bit
pushfd
pop eax

and eax,(~ 0x4000)

push eax
popfd

jmp krnlservice

.kil:

cmp eax,KRNL_KILL
jnz .self	;unknown call  kill caller

;kill	target in eax
mov ecx,[ebx+TSS.eax]
cmp edx,ecx		;target is self
jz .self

mov edx,ecx
call TSS_delete		;kill kernel shall always fail
mov [ebx+TSS.eax],eax

.end:

mov esp,ebp

iret	;with NT set switch back to caller task
jmp krnlservice
