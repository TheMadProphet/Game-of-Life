SECTION .data
    endl db "",0xa
    
    cleanCmd db `\u001b[0;0H\u001b[0J`
    lenCleanCmd equ $ - cleanCmd

    ;------------------------
    ; Change cell characters here
    ; NOTE: It needs to be a character, NOT string or unicode
    aliveChar db "O"
    deadChar  db `\'`

    ;------------------------
    ; Change map size here
    sizeX equ 35
    sizeY equ 18


SECTION .bss                    ; Section containing uninitialized data
    currentGen resb sizeX * sizeY   ; 
    nextGen resb sizeX * sizeY      ; We will store new generation here

    yMax resb 4
    xMax resb 4

    seed resb 4

    timeval:
        tv_sec  resb 4
        tv_usec resb 4

SECTION .text                   ; Section containing code

global _start
    

;---------------------------------------------------------------
; Algorithm:
;   1. Generate random map
;   2. Print currentGen
;   3. Create next generation in nextGen
;   4. Copy from nextGen to currentGen
;   5. Jump to step 2.
;---------------------------------------------------------------

_start:
    nop

    ; Generate seed
    rdtsc
    mov [seed], eax

    ; Set values for pause inbetween generations
    mov dword [tv_sec], 0           ; Number of seconds to pause
    mov dword [tv_usec], 250000000  ; Number of nano-seconds to pause

    ; Clear coordinate values
    xor ecx, ecx                ; ECX is y
    xor edx, edx                ; EDX is x

; Generate random map
gen_map:
    call random_next            ; Randomly generate cell

    mov byte [currentGen + edx + ecx], al   ; currentGen[y][x] = randCell
    mov byte [nextGen + edx + ecx], al      ; nextGen[y][x] = randCell

    ; x++
    inc dx                      ; Move onto next x
    cmp dx, sizeX               ; Did we reach end of row?
    jne gen_map                 ; If not, continue loop

    ; y++
    add cx, sizeX               ; Else move on next row
    xor dx, dx                  ; Reset x

    cmp cx, sizeX * sizeY       ; Are we on last row?
    jne gen_map                 ; If not, continue loop

    ; Clear coordinate values
    xor cx, cx                  ; ECX is y
    xor dx, dx                  ; EDX is x

; Prints the currentGen array
print_arr:

    ; Print current element
    mov eax, currentGen
    add eax, edx                ; Offset by x
    add eax, ecx                ; Offset by y
    mov ebx, 1                  ; Buffer size
    call print

    ; x++
    inc dx                      ; Move onto next x
    cmp dx, sizeX               ; Did we reach end of row?
    jne print_arr               ; If not, continue loop

    ; y++
    add cx, sizeX               ; Move on next row
    xor dx, dx                  ; Reset x

    ; We reached end of row, so print newline
    mov eax, endl
    mov ebx, 1
    call print

    cmp cx, sizeX * sizeY       ; Are we on last row?
    jne print_arr               ; If not, continue loop

    ; Reset coordinates
    xor ecx, ecx                ; ECX is y
    xor edx, edx                ; EDX is x

update:
    mov eax, currentGen         ; Get current generation's address
    add eax, edx                ; Offset it by x
    add eax, ecx                ; Offset it by y
    mov bl, [aliveChar]
    cmp byte [eax], bl          ; Is the cell alive?
    je case_alive               ; If yes, jump to alive case

case_dead:
    call get_neighbour          ; Get alive neighbour count
    cmp al, 3                   ; Is neighbour count 3?
    jne continue                ; If not, continue

    ; Otherwise we revive cell
    mov eax, nextGen            ; Get address of current cell in nextGen
    add eax, edx                ; Offset it by x
    add eax, ecx                ; Offset it by y
    mov bl, [aliveChar]
    mov byte [eax], bl          ; Set current cell to alive
    jmp continue                ; Continue

case_alive:
    call get_neighbour          ; Get alive neighbour count
    cmp al, 2                   ; Compare count to 2
    jb kill                     ; If count < 2 kill cell
    cmp al, 4                   ; Compare count to 4
    jae kill                    ; If count >= 4 kill cell
    jmp continue                ; Else, cell survives. Continue

kill:
    mov eax, nextGen            ; Get address of current cell in nextGen
    add eax, edx                ; Offset it by x
    add eax, ecx                ; Offset it by y
    mov ebx, [deadChar]
    mov byte [eax], bl          ; Set current cell to dead

continue:
    ; x++
    inc dx                      ; Move onto next x
    cmp dx, sizeX               ; Did we reach end of row?
    jne update                  ; If not, continue loop

    ; y++
    add cx, sizeX               ; Move on next row
    xor dx, dx                  ; Reset x

    cmp cx, sizeX * sizeY       ; Are we on last row?
    jne update                  ; If not, continue loop

    ; Reset coordinates
    xor ecx, ecx                ; ECX is y
    xor edx, edx                ; EDX is x

; Copies nextGen into currentGen
copy_to_arr:
    mov eax, nextGen            ; Put nextGen's adress in EAX
    add eax, edx                ; Offset it by x
    add eax, ecx                ; Offset it by y
    mov ebx, [eax]              ; 
    mov byte [currentGen + edx + ecx], bl   ; currentGen[y][x] = nextGen[y][x]

    ; x++
    inc dx                      ; Move onto next x
    cmp dx, sizeX               ; Did we reach end of row?
    jne copy_to_arr             ; If not, continue loop

    ; y++
    add cx, sizeX               ; Move on next row
    xor dx, dx                  ; Reset x

    cmp cx, sizeX * sizeY       ; Are we on last row?
    jne copy_to_arr             ; If not, continue loop

    ; Pause
    mov eax, 162
    mov ebx, timeval
    mov ecx, 0
    int 0x80

    ; Clear screen
    call clean

    xor cx, cx
    xor dx, dx
    jmp print_arr

    ; Exit (technically we will never reach here)
    mov eax, 1
    int 0x80



;---------------------------------------------------------------
; int get_neighbour -- Counts amount of alive neighbour cell has
;
; IN:
;   ECX: y coordinate
;   EDX: x coordinate
; OUT:
;   EAX: Alive neighbour count
;---------------------------------------------------------------

get_neighbour:
    ; Save registers
    push ebx
    push ecx
    push edx

    xor ebx, ebx                ; EBX will count neighbours

    ; Set xMax and yMax
    mov word [xMax], dx
    inc word [xMax]             ; xMax = x + 1
    mov word [yMax], cx
    add word [yMax], sizeX      ; yMax = y + 1

    ; Start from upper row
    sub cx, sizeX

loop_y:

    ; Start from left x
    mov dx, [xMax]
    sub dx, 2

loop_x:
    call valid                  ; Check if current coordinate is valid
    cmp al, 0                   ; 
    je hop                      ; If its invalid, continue loop

    ; If we're here, current coordinate is valid
    mov al, [deadChar]
    cmp byte [currentGen + ecx + edx], al  ; Check if current coordinate is alive
    je hop                      ; If its not, continue loop
    inc bl                      ; Else increase counter
hop:
    ; x++
    inc dx                      ; Move on next x
    cmp dx, [xMax]              ; compare x to xMax
    jle loop_x                  ; if x <= xMax, continue loop

    ; y++
    add cx, sizeX               ; Move on next row
    cmp cx, [yMax]              ; Compare y to yMax
    jle loop_y                  ; If y <= yMax, continue loop

    ; Restore old values
    pop edx
    pop ecx

    ; Check if current cell is alive
    ; If its alive, it will also be included in count
    ; so we need to remove it
    mov al, [deadChar]
    cmp byte [currentGen + edx + ecx], al
    je end                      ; If dead, jump to end
    dec bl                      ; If alive, don't count self
end:    
    mov al, bl                  ; Put result in EAX
    
    pop ebx                     ; Restore EBX
    ret




;---------------------------------------------------------------
; bool valid -- Checks whether a coordinate is within map bounds
;
; IN:
;   ECX: y coordinate
;   EDX: x coordinate
; OUT:
;   EDX: 1=valid | 0=invalid
;---------------------------------------------------------------

valid:
    ; Check for x
    cmp dx, 0                   ; Is x negative?
    jl falsify                  ; If so, return false
    cmp dx, sizeX               ; Is x >= xMax?
    jge falsify                 ; If so, return false

    ; Check for y
    cmp cx, 0                   ; Is y negative?
    jl falsify                  ; If so, return false
    cmp cx, sizeX * sizeY       ; Is y >= yMax?
    jge falsify                 ; If so, return false
    
    ; If we're here coordinate is valid. Return true
    mov eax, 1
    ret

falsify:
    ; If we're here coordinate is invalid. Return false
    mov eax, 0
    ret




;---------------------------------------------------------------
; void clean -- Clears console screen and sets cursor to (0,0)
;
; IN:
;   None
; OUT:
;   None
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


;---------------------------------------------------------------
; char random_next -- Randomly returns dead or alive cell character
;
; IN:
;   None
; OUT:
;   AL: Generated character
;---------------------------------------------------------------
random_next:
    ; Save registers
    push ebx
    push edx
    push ecx

    mov     ecx, [seed]
    mov     edx, ecx
    shr     edx, 6
    xor     ecx, edx
    mov     edx, ecx
    shl     edx, 12
    xor     ecx, edx
    mov     edx, ecx
    shr     edx, 14
    xor     ecx, edx
    mov     eax, 2685826577
    mul     ecx
    mov     [seed], ecx 
    
    pop ecx
    pop edx

    and al, 1
    jz .alive
    xor eax, eax

    mov bl, [deadChar]
    mov al, bl

    pop ebx
    ret
.alive:
    xor eax, eax

    mov bl, [aliveChar]
    mov al, bl
    
    pop ebx
    ret

