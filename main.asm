SECTION .data
    endl db "",0xa
    arrSize equ 20
    cleanCmd db `\u001b[0;0H\u001b[0J`
    lenCleanCmd equ $ - cleanCmd
	input:	db '--------------------'
			db '--------------------'
			db '--------------------'
			db '--------------------'
			db '--------------------'
			db '--------------------'
			db '--------------------'
			db '--------------------'
			db '--------X-X-X-------'
			db '--------X---X-------'
			db '--------X---X-------'
			db '--------X---X-------'
			db '--------X-X-X-------'
			db '--------------------'
			db '--------------------'
			db '--------------------'
			db '--------------------'
			db '--------------------'
			db '--------------------'
			db '--------------------'
    

SECTION .bss					; Section containing uninitialized data
    currentGen resb arrSize*arrSize	; 
    nextGen resb arrSize*arrSize 	; We will store new generation here
    x resb 4
    y resb 4

	timeval:
		tv_sec  resb 4
		tv_usec resb 4

SECTION .text					; Section containing code

global _start
    

;---------------------------------------------------------------
; Algorithm:
; 	1. Copy starting map (input) into currentGen and nextGen
;	2. Print currentGen
;	3. Create next generation in nextGen
;	4. Copy from nextGen to currentGen
;	5. Jump to step 2.
;
; Notes:
;	Inconsistent use of registers for x and y coordinates
;	TODO: Better input method
;	TODO: Have different sizes for x and y in map (arrSizeX/Y)
;---------------------------------------------------------------

_start:
    nop

	; Set values for pause inbetween generations
	mov dword [tv_sec], 0			; Number of seconds to pause
	mov dword [tv_usec], 250000000	; Number of nano-seconds to pause

	; Clear coordinate values
    xor ecx, ecx				; ECX is y
    xor edx, edx				; EDX is x

; Copy all input elements into currentGen and nextGen
copy_input:
	mov eax, input 				; Put input's adress in EAX
	add eax, edx				; Offset it by x
	add eax, ecx				; Offset it by y
	mov ebx, [eax]				; Place value stored in current location in EBX
	mov byte [currentGen + edx + ecx], bl	; currentGen[y][x] = input[y][x]
	mov byte [nextGen + edx + ecx], bl		; nextGen[y][x] = input[y][x]

	; x++
	inc edx						; Move onto next x
	cmp edx, arrSize			; Did we reach end of row?
	jne copy_input 				; If not, continue loop

	; y++
	add ecx, arrSize			; Else move on next row
	xor edx, edx				; Reset x

	cmp ecx, arrSize*arrSize 	; Are we on last row?
	jne copy_input				; If not, continue loop

	; Clear coordinate values
    xor ecx, ecx				; ECX is y
    xor edx, edx				; EDX is x

; Prints the currentGen array
print_arr:

	; Print current element
	mov eax, currentGen
	add eax, edx				; Offset by x
	add eax, ecx				; Offset by y
	mov ebx, 1					; Buffer size
	call print

	; x++
	inc edx						; Move onto next x
	cmp edx, arrSize			; Did we reach end of row?
	jne print_arr				; If not, continue loop

	; y++
	add ecx, arrSize			; Move on next row
	xor edx, edx				; Reset x

	; We reached end of row, so print newline
	mov eax, endl
	mov ebx, 1
	call print

	cmp ecx, arrSize*arrSize 	; Are we on last row?
	jne print_arr				; If not, continue loop

	; Clear coordinates
	; NOTE: Changed registers for x and y coordinates
	xor eax, eax				; EAX will be x
	xor ebx, ebx				; EBX will be y

update:
	mov ecx, currentGen 		; Get current generation's address
	add ecx, eax				; Offset it by x
	add ecx, ebx				; Offset it by y
	cmp byte [ecx], 'X'			; Is the cell alive?
	je case_alive 				; If yes, jump to alive case

case_dead:
	call get_neighbour 			; Get alive neighbour count
	cmp edx, 3					; Is neighbour count 3?
	jne continue 				; If not, continue

	; Otherwise we revive cell
	mov ecx, nextGen			; Get address of current cell in nextGen
	add ecx, eax				; Offset it by x
	add ecx, ebx				; Offset it by y
	mov byte [ecx], 'X'			; Set current cell to alive
	jmp continue 				; Continue

case_alive:
	call get_neighbour 			; Get alive neighbour count
	cmp edx, 2					; Compare count to 2
	jb kill						; If count < 2 kill cell
	cmp edx, 4					; Compare count to 4
	jae kill					; If count >= 4 kill cell
	jmp continue 				; Else, cell survives. Continue

kill:
	mov ecx, nextGen			; Get address of current cell in nextGen
	add ecx, eax				; Offset it by x
	add ecx, ebx				; Offset it by y
	mov byte [ecx], '-'			; Set current cell to dead

continue:
	; x++
	inc eax						; Move onto next x
	cmp eax, arrSize			; Did we reach end of row?
	jne update  				; If not, continue loop

	; y++
	add ebx, arrSize			; Move on next row
	xor eax, eax				; Reset x

	cmp ebx, arrSize*arrSize 	; Are we on last row?
	jne update 					; If not, continue loop

	; Clear coordinates
	; NOTE: Again, changed registers for x and y coordinates
	xor ecx, ecx				; ECX is y
	xor edx, edx				; EDX is x

; Copies nextGen into currentGen
copy_to_arr:
	mov eax, nextGen			; Put nextGen's adress in EAX
	add eax, edx				; Offset it by x
	add eax, ecx				; Offset it by y
	mov ebx, [eax]				; Place value stored in current location in EBX
	mov byte [currentGen + edx + ecx], bl	; currentGen[y][x] = input[y][x]

	; x++
	inc edx						; Move onto next x
	cmp edx, arrSize			; Did we reach end of row?
	jne copy_to_arr 			; If not, continue loop

	; y++
	add ecx, arrSize			; Move on next row
	xor edx, edx				; Reset x

	cmp ecx, arrSize*arrSize 	; Are we on last row?
	jne copy_to_arr				; If not, continue loop

	; Pause
	mov eax, 162
	mov ebx, timeval
	mov ecx, 0
	int 0x80

	; Clear screen
	call clean

	xor ecx, ecx
	xor edx, edx
	jmp print_arr

    ; Exit (technically we will never reach here)
    mov eax, 1
    int 0x80




;---------------------------------------------------------------
; int get_neighbour -- Counts amount of alive neighbour cell has
;
; IN:
;	EAX: x coordinate
;	EBX: y coordinate
; OUT:
;	EAX: Alive neighbour count
;
; NOTES:
;	TODO: Store xMax and yMax in EDI and ESI (or EBP)
;---------------------------------------------------------------

get_neighbour:
	; Save registers
	push ecx
	push eax
	push ebx

	xor ecx, ecx 				; ECX will count neighbours

	; x and y will represent xMax and yMax
	mov dword [x], eax
	inc dword [x]				; xMax = x + 1
	mov dword [y], ebx
	add dword [y], arrSize 		; yMax = y + 1

	; Start from upper row
	sub ebx, arrSize

loop_y:

	; Start from left x
	mov eax, [x]
	sub eax, 2

loop_x:
	call valid 					; Check if current coordinate is valid
	cmp edx, 0 					; 
	je hop 						; If its invalid, continue loop

	; If we're here, current coordinate is valid
	cmp byte [currentGen + eax + ebx], '-'	; Check if current coordinate is alive
	je hop 						; If its not, continue loop
	inc ecx						; Else increase counter
hop:
	; x++
	inc eax						; Move on next x
	cmp eax, [x]				; compare x to xMax
	jle loop_x 					; if x <= xMax, continue loop

	; y++
	add ebx, arrSize 			; Move on next row
	cmp ebx, [y]				; Compare y to yMax
	jle loop_y 					; If y <= yMax, continue loop

	; Restore old values
	pop ebx
	pop eax

	; Check if current cell is alive
	; If its alive, it will also be included in count
	; so we need to remove it
	cmp byte [currentGen + ebx + eax], '-'
	je end 						; If dead, jump to end
	dec ecx						; If alive, don't count self
end:	
	mov edx, ecx				; Put result in EAX
	
	pop ecx ; Restore ECX
	ret




;---------------------------------------------------------------
; bool valid -- Checks whether a coordinate is within map bounds
;
; IN:
;	EAX: x coordinate
;	EBX: y coordinate
; OUT:
;	EDX: 1=valid | 0=invalid
;---------------------------------------------------------------

valid:
	; Check for x
	cmp eax, 0					; Is x negative?
	jl falsify 					; If so, return false
	cmp eax, arrSize 			; Is x >= xMax?
	jge falsify 				; If so, return false

	; Check for y
	cmp ebx, 0					; Is y negative?
	jl falsify 					; If so, return false
	cmp ebx, arrSize*arrSize	; Is y >= yMax?
	jge falsify 				; If so, return false
	
	; If we're here coordinate is valid. Return true
	mov edx, 1
	ret

falsify:
	; If we're here coordinate is invalid. Return false
	mov edx, 0
	ret




;---------------------------------------------------------------
; void clean -- Clears console screen and sets cursor to (0,0)
;
; IN:
;	None
; OUT:
;	None
;---------------------------------------------------------------

clean:
	; Save registers
	push ebx
	push eax

	; Set cursor position to (0,0) and clean screen
	mov eax, cleanCmd
	mov ebx, lenCleanCmd
	call print

	; Restore registers	
	pop eax
	pop ebx

	ret


;---------------------------------------------------------------
; void print  --  Prints message to stdout
;
; IN:
;   EAX: Message to print
;   EBX: Message size
; OUT:
;   None
;
; Notes:
;---------------------------------------------------------------

print:
    ; Save registers
    push eax
    push ebx
    push ecx
    push edx
    
    ; Print message
    mov ecx, eax    ;move message in ecx
    mov edx, ebx    ;move message length in edx
    mov eax, 4      ;sys_write
    mov ebx, 1      ;stdout
    int 0x80        ;call print
    
    ; Recover registers
    pop edx
    pop ecx
    pop ebx
    pop eax

    ret

