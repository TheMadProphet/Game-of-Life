gol: main.o
	ld -m elf_i386 -o gol main.o
main.o: main.asm
	nasm -f elf -g -F dwarf main.asm
