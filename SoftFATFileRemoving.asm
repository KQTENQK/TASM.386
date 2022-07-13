.386

Data segment use16
	SectorBuffer db 512 dup(?)
	SectorID dd ?
	SectorAmount dw 1
	SectorBufferAlloc dw SectorBuffer
	SectorBufferAllocArea dw Data

	IOBuffer db 255
	IOBufferLength db ?
	db 255 dup(?)

	PreInputMsg db 0Dh, 0Ah,"Enter path:", 0Dh, 0Ah, "$"
	UnexistingDirectoryMsg db 0Dh, 0Ah,"Cannot find directory or file.$"
	InvalidDirInputMsg db 0Dh, 0Ah, "Invalid input.$"
	SuccessDeletingMsg db 0Dh, 0Ah,"Deleted", 0Dh, 0Ah, "$"
	ModeMsg db 0Dh, 0Ah, "Mode: Restore - 0, Delete - 1?", 0Dh, 0Ah, "$"
	FirstRestoringLetterMsg db 0Dh, 0Ah, "First letter:", 0Dh, 0Ah, "$"
	RestoredMsg db 0Dh, 0Ah, "Restored.$"
	SmthWentWrongMsg db 0Dh, 0Ah, "Error while reading disk.$"

	Names db 7 dup (11 dup (20h))
	Depth db ?
	LogicalDiskID db ?
	RootSector dd ?
	Clasters dd ?
	ClasterSize db ?

	Mode db ?
Data ends

Funcs segment use16
	assume cs:Funcs, ds:Data

	IsDot db 0
	Iteration db 0
	SectorCount db 0
	NameAdress dw 0

	;si <- 8.3 name, ds:SectorID <- id
	TryFind proc far
	NextSector:
		mov word ptr cs:NameAdress, si
		mov al, byte ptr ds:LogicalDiskID
		mov cx, 0FFFFh
		lea bx, ds:SectorID
		int 25h
		pop ax

		mov cs:Iteration, 16
		mov cx, 16
		lea bp, ds:SectorBuffer

	AnalyzeFileNameNext:
		mov cs:Iteration, cl
		mov cx, 11
	AnalyzeFileName:
		mov al, byte ptr ds:[bp]

		cmp al, 0
		je short BadEndInfo

		cmp ds:[si], al
		jne short NextInfo
		inc bp
		inc si
		loop AnalyzeFileName
		mov si, word ptr cs:NameAdress
		sub bp, 11
		stc
		jmp short TryFindRet

	NextInfo:
		movzx cx, byte ptr cs:Iteration
		mov ax, 16
		sub ax, cx
		shl ax, 5
		lea bp, ds:SectorBuffer
		add bp, ax
		mov si, word ptr cs:NameAdress
		loop AnalyzeFileNameNext
		mov si, word ptr cs:NameAdress
		mov al, ds:ClasterSize
		cmp byte ptr cs:SectorCount, al
		jae short BadEndInfo
		inc byte ptr cs:SectorCount
		inc dword ptr ds:SectorID
		jmp short NextSector

	BadEndInfo:
		clc

	TryFindRet:
		mov cs:Iteration, 0
		mov cs:SectorCount, 0
		ret
	TryFind endp

	;si <- input, bp <- output; CF <- searchDot
	;CF -> invalid, bl -> catalogCount

	ParseNames proc far

		jnc short ParseBegin
		mov cs:IsDot, 1
    
	ParseBegin:
		mov di, 0                                                         
		mov bl, 0                                                         
    
		movzx cx, byte ptr ds:[si + 1]                                      
		add si, 5                                                          
		sub cx, 3                                                           

	ParseCycle:
		cmp ds:[si], byte ptr '\'                                       
		jne short NotDir                                           
    
		inc bl                                                             
		add bp, 11                                                         
		xor di, di                                                          
		jmp short EndParseCycle
    
	NotDir:
		mov al, ds:[si]                                                    
		mov ds:[bp + di], al                                                  
		inc di                                                             

	EndParseCycle:
		inc si
		loop short ParseCycle

		cmp cs:IsDot, 1
		je EndParsing

		mov cx, di                                                          
		xor di, di                                                          
    
	FindDot:
		cmp ds:[bp + di], byte ptr '.'                                     
		jne short NotFound                                            
    
		cmp di, 8
		je short FormUp                                              
    
		mov byte ptr ds:[bp + di], 20h                                        
    
		mov al, ds:[bp + di + 1]
		mov byte ptr ds:[bp + di + 1], 20h                                      
    
		mov cx, ds:[bp + di + 2]
		mov word ptr ds:[bp + di + 2], 2020h                                     
    
		mov ds:[bp + 8], al                                                       
		mov ds:[bp + 9], cx                                                   
		jmp short EndParsing
    
	NotFound:
		inc di
		loop short FindDot
		jmp short ParsingInvalid   
   
	FormUp:
		mov cx, 3    
		
	FormUpCycle:
		mov al, ds:[bp + di + 1]
		mov ds:[bp + di], al
		inc di
    
		loop short FormUpCycle
    
		mov byte ptr ds:[bp + di], 20h

	EndParsing:
		clc
		jmp short ParseRet

	ParsingInvalid:
		stc

	ParseRet:
		ret

	ParseNames endp
	
Funcs ends

Program segment use16
	assume cs:Program, ds:Data

Main:
	mov ax, Data
	mov ds, ax

ModeSelectionAgain:
	mov ah, 9h
	lea dx, ds:ModeMsg
	int 21h

	mov ah, 0Ah
	lea dx, ds:IOBuffer
	int 21h

	cmp ds:IOBufferLength, 1
	jne short ModeSelectionAgain
	mov al, ds:IOBuffer + 2
	and al, 1
	cmp al, 0
	jne short ModeSelectionAgain

	mov al, ds:IOBuffer + 2
	sub al, 30h
	mov ds:Mode, al

	mov ah, 9h
	lea dx, ds:PreInputMsg
	int 21h

	mov ah, 0Ah
	lea dx, ds:IOBuffer
	int 21h

	cmp ds:IOBufferLength, 3
	jbe InvalidDirInput

	movzx cx, byte ptr ds:IOBufferLength
	lea si, ds:IOBuffer + 2

ValidateInputStr:
	cmp byte ptr ds:[si], "."
	je short ValidateNext
	cmp byte ptr ds:[si], "/"
	je short ValidateNext
	cmp byte ptr ds:[si], "\"
	je short ValidateNext
	cmp byte ptr ds:[si], ":"
	je short ValidateNext
	cmp byte ptr ds:[si], 30h
	jb InvalidDirInput
	cmp byte ptr ds:[si], 39h
	jbe ValidateNext
	cmp byte ptr ds:[si], 41h
	jb InvalidDirInput
	cmp byte ptr ds:[si], 5Ah
	jbe short ValidateNext
	cmp byte ptr ds:[si], 61h
	jb InvalidDirInput
	cmp byte ptr ds:[si], 7Ah
	ja InvalidDirInput
	and byte ptr ds:[si], 11011111b

ValidateNext:
	inc si
	loop ValidateInputStr

	mov al, ds:IOBuffer + 2
	sub al, 41h
	mov byte ptr ds:LogicalDiskID, al
	jc InvalidDirInput
	lea si, ds:IOBuffer
	lea bp, ds:Names
	clc
	call ParseNames
	mov byte ptr ds:Depth, bl

	cmp ds:Mode, 0
	jne short NotRestoring
	mov al, 11
	mul bl
	lea si, ds:Names
	add si, ax
	mov byte ptr ds:[si], 0E5h

NotRestoring:
	mov al, ds:LogicalDiskID
	mov dword ptr ds:SectorID, 0
	mov cx, 0FFFFh
	lea bx, SectorID
	int 25h
	pop ax
	jc SmthWentWrong
	mov ax, word ptr ds:SectorBuffer + 16h
	movzx bx, byte ptr ds:SectorBuffer + 10h
	mul bx
	push ax
	movzx eax, dx
	shl eax, 10h
	pop ax
	mov edx, 0
	movzx ecx, byte ptr ds:SectorBuffer + 0Dh
	mov byte ptr ds:ClasterSize, cl
	movzx ecx, word ptr ds:SectorBuffer + 0Eh
	add eax, ecx
	mov dword ptr ds:RootSector, eax
	mov ax, word ptr ds:SectorBuffer + 11h
	shr ax, 4
	movzx eax, ax
	mov ebx, dword ptr ds:RootSector
	add ebx, eax
	mov dword ptr ds:Clasters, ebx
	mov eax, dword ptr ds:RootSector

	mov dword ptr ds:SectorID, eax
	lea si, ds:Names

FindFileCycle:
	call TryFind
	jnc UnExistingDirectoryInput
	cmp ds:Depth, 0
	je short Act
	add bp, 26
	mov ax, word ptr ds:[bp]
	sub ax, 2
	movzx bx, byte ptr ds:ClasterSize
	mov dx, 0
	mul bx
	push ax
	mov ax, dx
	shl eax, 10h
	pop ax
	mov ebx, dword ptr ds:Clasters
	add eax, ebx
	mov dword ptr ds:SectorID, eax
	add si, 11
	dec byte ptr ds:Depth
	jmp short FindFileCycle

Act:
	cmp ds:Mode, 0
	je short Restore

Remove:
	mov byte ptr ds:[bp], 0E5h
	mov al, byte ptr ds:LogicalDiskID
	mov cx, 0FFFFh
	lea bx, ds:SectorID
	int 26h
	pop ax

	mov ah, 9h
	lea dx, ds:SuccessDeletingMsg
	int 21h

	jmp short Final

Restore:
	mov ah, 9h
	lea dx, ds:FirstRestoringLetterMsg
	int 21h

	mov ah, 0Ah
	lea dx, ds:IOBuffer
	int 21h
	
	mov al, ds:IOBuffer + 2
	cmp al, 41h
	jb short InvalidDirInput
	cmp al, 5Ah
	jbe short IsOkLetter
	cmp al, 61h
	jb short InvalidDirInput
	cmp al, 7Ah
	ja short InvalidDirInput
IsOkLetter:
	and al, 11011111b
	mov byte ptr ds:[bp], al
	mov al, byte ptr ds:LogicalDiskID
	mov cx, 0FFFFh
	lea bx, ds:SectorID
	int 26h
	pop ax

	mov ah, 9h
	lea dx, ds:RestoredMsg
	int 21h

	jmp short Final

UnExistingDirectoryInput:
	mov ah, 9h
	lea dx, ds:UnexistingDirectoryMsg
	int 21h
	jmp short Final

SmthWentWrong:
	mov ah, 9h
	lea dx, ds:SmthWentWrongMsg
	int 21h

InvalidDirInput:
	mov ah, 9h
	lea dx, ds:InvalidDirInputMsg
	int 21h

Final:
	mov ah, 4ch
	int 21h

Program ends
	End Main
