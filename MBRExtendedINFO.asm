.386

Data segment use16
	Setter db 16, 0
	Amount db 1 
	db 0
	dw Buffer
	dw Data
	LBAId dq 0

	Buffer db 512 dup(?)

	LBAIdFirst dq 0

	NormalConditionOutput db 0Dh, 0Ah, "Size: ??????????d, $"
	SizeOutput db "???? MBytes.$"
	NoPartitionMsg db 0Dh, 0Ah, "No existing partitions.$"
	NoExtendedPartitionMsg db 0Dh, 0Ah, "No extended partitions.$"
	EndMsg db 0Dh, 0Ah, "No more logical disks exist.$"
	InvalidIdMsg db 0Dh, 0Ah, "Invalid disk ID.$"
	DiskID db 80h
	DiskIDParamSetupMsg db 0Dh, 0Ah, "Enter disk ID: $"
	ReadBuffer db 10, 1, 10 dup (?)

	RelJmpIP dw ?
	RelJmpCS dw ?
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

	TryDefine proc far

	BeginTryDefine:
		mov ah, 42h
		mov dl, ds:DiskID
		lea si, Setter
		int 13h

		lea si, ds:Buffer
		add si, 458
		mov eax, ds:[si]
		cmp eax, 0h
		je EndTryDefine
		push word ptr ds:[si]
		push word ptr ds:[si + 2]

		call ToBCD
		lea bp, ds:NormalConditionOutput
		add bp, 17
		mov cx, 10
	NormalOutputCycle:
		pop ax
		or al, 30h
		mov ds:[bp], al
		dec bp
		loop NormalOutputCycle

		mov cx, 9
		inc bp

	FormHexSizeCycle:
		mov ah, ds:[bp]
		cmp ah, 30h
		jne short FormattedHexSize
		mov byte ptr ds:[bp], 20h
		inc bp
		loop FormHexSizeCycle
	FormattedHexSize:

		mov ah, 9h
		lea dx, ds:NormalConditionOutput
		int 21h

		pop ax
		shl eax, 10h
		pop ax
		shr eax, 11

		call ToBCD
		pop ax
		or al, 30h
		mov ds:SizeOutput + 3, al
		pop ax
		or al, 30h
		mov ds:SizeOutput + 2, al
		pop ax
		or al, 30h
		mov ds:SizeOutput + 1, al
		pop ax
		or al, 30h
		mov ds:SizeOutput, al
		
		add sp, 12

		mov cx, 3
		push di
		lea di, ds:SizeOutput

	FormSizeCycle:
		mov ah, ds:[di]
		cmp ah, 30h
		jne short FormattedSize
		mov byte ptr ds:[di], 20h
		inc di
		loop FormSizeCycle
	FormattedSize:
		pop di

		mov ah, 9h
		lea dx, ds:SizeOutput
		int 21h

	MoveNext:
		add si, 12
		mov eax, ds:[si]
		cmp eax, 0h
		je short EndTryDefine
		mov ecx, dword ptr ds:LBAIdFirst + 4
		mov ebx, dword ptr ds:LBAIdFirst
		add eax, ebx
		adc ecx, 0
		mov dword ptr ds:LBAId, eax
		mov dword ptr ds:LBAId + 4, ecx
		jmp BeginTryDefine

	EndTryDefine:
		lea dx, ds:EndMsg
		mov ah, 9h
		int 21h
		ret
	TryDefine endp
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
	lea si, Setter
	int 13h

	jnc short DiskExisting
	mov ah, 9h
	lea dx, ds:InvalidIdMsg
	int 21h
	jmp Final

DiskExisting:

	mov ah, 42h
	mov dl, ds:DiskID
	lea si, Setter
	int 13h

	lea si, ds:Buffer
	add si, 450
	mov al, ds:[si]
	cmp al, 0
	jne short PartitionsExisting

	mov ah, 9h
	lea dx, ds:NoPartitionMsg
	int 21h

PartitionsExisting:
	cmp al, 0
	jne short NotZero
	lea dx, ds:NoExtendedPartitionMsg
	mov ah, 9h
	int 21h
	jmp short Final
NotZero:
	cmp al, 05h
	jne short Not05H

Extended:
	add si, 4
	mov eax, ds:[si]
	mov dword ptr ds:LBAId, eax
	mov dword ptr ds:LBAIdFirst, eax
	call TryDefine
	jmp short Final

Not05H:
	cmp al, 0Fh
	je short Extended

Not0FH:
	cmp si, 498
	jne short Next
	lea dx, ds:NoExtendedPartitionMsg
	mov ah, 9h
	int 21h
	jmp short Final
Next:
	add si, 10h
	mov al, ds:[si]
	jmp short PartitionsExisting

Final:
	mov ah, 4ch
	int 21h

Program ends
	End Main
