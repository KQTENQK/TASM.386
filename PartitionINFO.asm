.386

Data segment use16
	Params db 16, 0
	Amount db 1 
	db 0
	dw Buffer
	dw Data
	LBA dq 0

	Buffer db 512 dup(?)

	NoPartitionMsg db 0Dh, 0Ah, "No existing partitions.$"
	PrimaryPartitionMsg db 0Dh, 0Ah, "Primary partition: CHS: ($"
	ExtendedPartitionMsg db 0Dh, 0Ah, "Extended partition: CHS: ($"
	InvalidIdMsg db 0Dh, 0Ah, "Invalid disk ID.$"
	CHSMsg db "    ;    ;    ).$"
	LBAMsg db 0Dh, 0Ah, "LBA:           .$"
	SizeMsg db 0Dh, 0Ah, "Size:      MBytes.$"
	RelJmpIP dw ?
	RelJmpCS dw ?
	DiskID db 80h
	DiskIDParamSetupMsg db 0Dh, 0Ah, "Enter disk ID: $"
	ReadBuffer db 10, 1, 10 dup (?)
Data ends

Funcs segment use16
	assume cs:Funcs, ds:Data

	DecimalCharsToNumber proc far
		mov bp, si
		inc si
		movsx cx, byte ptr ds:[si]
		add si, cx

		mov dx, 0
		mov dl, 1

		ToHexCycle:
			mov al, byte ptr ds:[si]

			cmp al, 2Dh
			je short IsNegativeDecimal
			cmp al, 2Bh
			je short IsPositiveDecimal

			cmp al, 30h
			jl short NotDecimalValue

			cmp al, 39h 
			jg short NotDecimalValue

			sub al, 30h
			mul dl
			add dh, al

			jo short IsNegativeDecimal

			mov al, 10
			mul dl
			mov dl, al

			dec si

			loop ToHexCycle

			jmp short NotDecimalValue

		IsPositiveDecimal:
			STC

		ReturnDecimalCharsToNumber:
			ret

		IsNegativeDecimal:
			cmp byte ptr ds:[bp + 2], 2Dh
			jne short NotDecimalValue

			cmp dh, 80h
			ja short NotDecimalValue

			STC
			neg dh
			jmp short ReturnDecimalCharsToNumber

		NotDecimalValue:
			
			CLC
			jmp short ReturnDecimalCharsToNumber

	DecimalCharsToNumber endp


	ToBCD proc far
		pop dx
		mov ds:RelJmpIP, dx
		pop dx
		mov ds:RelJmpCS, dx
		mov dx, 0
		mov ecx, 1000000000

	CycleCMP:
		cmp eax, ecx
		jb short PushBCDDigit
		inc dx
		sub eax, ecx
		jmp short CycleCMP

	PushBCDDigit:
		push dx
		mov ebx, eax
		mov edx, 0
		mov eax, ecx
		mov ebp, 10
		div ebp
		mov ecx, eax
		mov eax, ebx
		cmp ecx, 0
		je short EndToBCD
		jmp short CycleCMP

	EndToBCD:
		mov dx, ds:RelJmpCS
		push dx
		mov dx, ds:RelJmpIP
		push dx
		ret
		;(stack = 10 words BCD)
	ToBCD endp
Funcs ends

Program segment use16
	assume cs:Program, ds:Data

Main:
	mov ax, Data
	mov ds, ax

	mov ah, 9h
	lea dx, ds:DiskIDParamSetupMsg
	int 21h

	mov ah, 0Ah
	lea dx, ds:ReadBuffer
	int 21h

	mov si, dx
	call DecimalCharsToNumber
	add dh, 80h
	mov ds:DiskID, dh

	mov ah, 42h
	mov dl, ds:DiskID
	lea si, Params
	int 13h

	jnc short DiskExisting
	mov ah, 9h
	lea dx, ds:InvalidIdMsg
	int 21h
	jmp Final

DiskExisting:
	lea si, ds:Buffer
	add si, 450
	mov al, ds:[si]
	cmp al, 0
	jne short PartitionsExisting

	mov ah, 9h
	lea dx, ds:NoPartitionMsg
	int 21h
	jmp EndAnalyzing

PartitionsExisting:
	cmp al, 0
	jne short NotZero
	jmp EndAnalyzing

NotZero:
	cmp al, 05h
	jne short Not05H

Extended:
	lea dx, ds:ExtendedPartitionMsg
	mov ah, 9h
	int 21h
	jmp short StartAnalyzing

Not05H:
	cmp al, 0Fh
	jne short Not0FH
	jmp short Extended

Not0FH:
	cmp si, 510
	jae EndAnalyzing
	
	lea dx, ds:PrimaryPartitionMsg
	mov ah, 9h
	int 21h

StartAnalyzing:
	sub si, 3
	movzx ax, byte ptr ds:[si] ; Head
	mov dx, ax

	inc si
	movzx eax, word ptr ds:[si] ;CS
	mov bx, ax ;->S
	and bx, 0000000000111111b
	and ax, 1111111111000000b
	mov ch, al
	shr ch, 6
	shr ax, 8
	mov ah, ch ; ax = C, bx = S
	push bx
	push dx

	call ToBCD
	pop ax
	or al, 30h
	mov ds:CHSMsg + 3, al
	pop ax
	or al, 30h
	mov ds:CHSMsg + 2, al
	pop ax
	or al, 30h
	mov ds:CHSMsg + 1, al
	pop ax
	or al, 30h
	mov ds:CHSMsg, al

	add sp, 12

	pop bx
	movzx eax, bx
	call ToBCD
	pop ax
	or al, 30h
	mov ds:CHSMsg + 8, al
	pop ax
	or al, 30h
	mov ds:CHSMsg + 7, al
	pop ax
	or al, 30h
	mov ds:CHSMsg + 6, al
	pop ax
	or al, 30h
	mov ds:CHSMsg + 5, al

	add sp, 12

	mov eax, 0
	pop ax
	call ToBCD
	pop ax
	or al, 30h
	mov ds:CHSMsg + 13, al
	pop ax
	or al, 30h
	mov ds:CHSMsg + 12, al
	pop ax
	or al, 30h
	mov ds:CHSMsg + 11, al
	pop ax
	or al, 30h
	mov ds:CHSMsg + 10, al

	add sp, 12
	
	lea dx, ds:CHSMsg
	mov ah, 9h
	int 21h

	add si, 6
	mov eax, dword ptr ds:[si]
	call ToBCD

	push si
	lea si, ds:LBAMsg
	add si, 16
	mov cx, 10

LBAMsgBeg:
	pop ax
	or al, 30h
	mov byte ptr ds:[si], al
	dec si
	loop LBAMsgBeg

	pop si

	lea dx, ds:LBAMsg
	mov ah, 9h
	int 21h

	add si, 4
	mov eax, dword ptr ds:[si]
	
	shr eax, 11

	call ToBCD
	pop ax
	or al, 30h
	mov ds:SizeMsg + 12, al
	pop ax
	or al, 30h
	mov ds:SizeMsg + 11, al
	pop ax
	or al, 30h
	mov ds:SizeMsg + 10, al
	pop ax
	or al, 30h
	mov ds:SizeMsg + 9, al

	add sp, 12

	lea dx, ds:SizeMsg
	mov ah, 9h
	int 21h

Next:
	add si, 8
	mov al, ds:[si]
	jmp PartitionsExisting

EndAnalyzing:

Final:
	mov ah, 4ch
	int 21h

Program ends
	End Main