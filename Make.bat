@color 2f
nasm -f bin boot.asm -o boot.bin
@echo --------------------------------------------
@pause > nul
nasm -f bin TSS.asm -o oskrnl.bin
@echo --------------------------------------------
@pause > nul
nasm -f bin shell.asm -o shell.bin
@echo --------------------------------------------
@pause > nul
nasm -f bin hello.asm -o hello.bin
@echo --------------------------------------------
@pause > nul
nasm -f bin badcode.asm -o badcode.bin
@echo --------------------------------------------
@pause > nul
nasm -f bin count.asm -o count.bin
@echo --------------------------------------------
@pause > nul
nasm -f bin kill.asm -o kill.bin
@echo --------------------------------------------
@pause > nul
nasm -f bin spin.asm -o spin.bin
@echo --------------------------------------------
@pause > nul
nasm -f bin code.asm -o code.bin
@echo --------------------------------------------
@pause > nul