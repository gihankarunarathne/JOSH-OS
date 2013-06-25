;#################################################### 
;#				    gckarunarathne@gmail.com		#
;#					H.M.G.C.KARUNARATHNE			#
;####################################################

;*****************start of the kernel code***************
[org 0x000]
[bits 16]

[SEGMENT .text]

;START #####################################################
    mov ax, 0x0100			;location where kernel is loaded
    mov ds, ax
    mov es, ax
    
    cli
    mov ss, ax				;stack segment
    mov sp, 0xFFFF			;stack pointer at 64k limit
    sti

    push dx
    push es
    xor ax, ax
    mov es, ax
    cli
    mov word [es:0x21*4], _int0x21	; setup interrupt service
    mov [es:0x21*4+2], cs
    sti
    pop es
    pop dx

    mov si, strWelcomeMsg   ; load message
    mov al, 0x01            ; request sub-service 0x01
    int 0x21

	call _shell				; call the shell
    
    int 0x19                ; reboot
;END #######################################################

_int0x21:
    _int0x21_ser0x01:       ;service 0x01
    cmp al, 0x01            ;see if service 0x01 wanted
    jne _int0x21_end        ;goto next check (now it is end)
    
	_int0x21_ser0x01_start:
    lodsb                   ; load next character
    or  al, al              ; test for NUL character
    jz  _int0x21_ser0x01_end
    mov ah, 0x0E            ; BIOS teletype
    mov bh, 0x00            ; display page 0
    mov bl, 0x07            ; text attribute
    int 0x10                ; invoke BIOS
    jmp _int0x21_ser0x01_start
    _int0x21_ser0x01_end:
    jmp _int0x21_end

    _int0x21_end:
    iret

_shell:
	_shell_begin:
	;move to next line
	call _display_endl

	;display prompt
	call _display_prompt

	;get user command
	call _get_command
	
	;split command into components
	call _split_cmd

	;check command & perform action

	; empty command
	_cmd_none:		
	mov si, strCmd0
	cmp BYTE [si], 0x00
	jne	_cmd_ver		;next command
	jmp _cmd_done
	
	; display version
	_cmd_ver:		
	mov si, strCmd0
	mov di, cmdVer
	mov cx, 4
	repe	cmpsb
	jne	_cmd_help		;next command
	
	call _display_endl
	mov si, strOsName		;display version
	mov al, 0x01
    int 0x21
	call _display_space
	mov si, txtVersion		;display version
	mov al, 0x01
    int 0x21
	call _display_space

	mov si, strMajorVer		
	mov al, 0x01
    int 0x21
	mov si, strMinorVer
	mov al, 0x01
    int 0x21
	jmp _cmd_done

	; display set of commands and help
	_cmd_help:		
	mov si, strCmd0
	mov di, cmdHelp
	mov cx, 4
	repe	cmpsb
	jne	_cmd_prop		;next command
	
	call _display_endl
	mov si, hTitle	;print help
	call _display
	mov si, helpexit
	call _display
	mov si, hHelp
	call _display
	mov si, hVer
	call _display
	mov si, hInfo
	call _display
	jmp _cmd_done

	; display hardware information
	_cmd_prop:
	mov si, strCmd0
	mov di, cmdProp
	mov cx, 4
	repe	cmpsb
	jne	_cmd_exit		;next command
	
	call _display_endl
	call _display_endl

	mov si,decarate
	call _display
	mov si,propHead
	call _display
	mov si,decarate
	call _display
	call _display_endl

	call _cpu		;cpu details
	call _display_endl	
	call _ram		;RAM size
	call _otherInfo		;Other information

	call _display_endl
	mov si,decarate
	call _display	
	call _display_endl
	jmp _cmd_done

	; exit shell
	_cmd_exit:		
	mov si, strCmd0
	mov di, cmdExit
	mov cx, 5
	repe	cmpsb
	jne	_cmd_unknown		;next command

	je _shell_end			;exit from shell

	_cmd_unknown:
	call _display_endl
	mov si, msgUnknownCmd		;unknown command
	mov al, 0x01
    int 0x21

	_cmd_done:

	;call _display_endl
	jmp _shell_begin
	
	_shell_end:
	ret

_get_command:
	;initiate count
	mov BYTE [cmdChrCnt], 0x00
	mov di, strUserCmd

	_get_cmd_start:
	mov ah, 0x10		;get character
	int 0x16

	cmp al, 0x00		;check if extended key
	je _extended_key
	cmp al, 0xE0		;check if new extended key
	je _extended_key

	cmp al, 0x08		;check if backspace pressed
	je _backspace_key

	cmp al, 0x0D		;check if Enter pressed
	je _enter_key

	mov bh, [cmdMaxLen]		;check if maxlen reached
	mov bl, [cmdChrCnt]
	cmp bh, bl
	je	_get_cmd_start

	;add char to buffer, display it and start again
	mov [di], al			;add char to buffer
	inc di					;increment buffer pointer
	inc BYTE [cmdChrCnt]	;inc count

	mov ah, 0x0E			;display character
	mov bl, 0x07
	int 0x10
	jmp	_get_cmd_start

	_extended_key:			;extended key - do nothing now
	jmp _get_cmd_start

	_backspace_key:
	mov bh, 0x00			;check if count = 0
	mov bl, [cmdChrCnt]
	cmp bh, bl
	je	_get_cmd_start		;yes, do nothing
	
	dec BYTE [cmdChrCnt]	;dec count
	dec di

	;check if beginning of line
	mov	ah, 0x03		;read cursor position
	mov bh, 0x00
	int 0x10

	cmp dl, 0x00
	jne	_move_back
	dec dh
	mov dl, 79
	mov ah, 0x02
	int 0x10

	mov ah, 0x09		; display without moving cursor
	mov al, ' '
    mov bh, 0x00
    mov bl, 0x07
	mov cx, 1			; times to display
    int 0x10
	jmp _get_cmd_start

	_move_back:
	mov ah, 0x0E		; BIOS teletype acts on backspace!
    mov bh, 0x00
    mov bl, 0x07
    int 0x10
	mov ah, 0x09		; display without moving cursor
	mov al, ' '
    mov bh, 0x00
    mov bl, 0x07
	mov cx, 1			; times to display
    int 0x10
	jmp _get_cmd_start

	_enter_key:
	mov BYTE [di], 0x00
	ret

_split_cmd:
	;adjust si/di
	mov si, strUserCmd
	;mov di, strCmd0

	;move blanks
	_split_mb0_start:
	cmp BYTE [si], 0x20
	je _split_mb0_nb
	jmp _split_mb0_end

	_split_mb0_nb:
	inc si
	jmp _split_mb0_start

	_split_mb0_end:
	mov di, strCmd0

	_split_1_start:			;get first string
	cmp BYTE [si], 0x20
	je _split_1_end
	cmp BYTE [si], 0x00
	je _split_1_end
	mov al, [si]
	mov [di], al
	inc si
	inc di
	jmp _split_1_start

	_split_1_end:
	mov BYTE [di], 0x00

	;move blanks
	_split_mb1_start:
	cmp BYTE [si], 0x20
	je _split_mb1_nb
	jmp _split_mb1_end

	_split_mb1_nb:
	inc si
	jmp _split_mb1_start

	_split_mb1_end:
	mov di, strCmd1

	_split_2_start:			;get second string
	cmp BYTE [si], 0x20
	je _split_2_end
	cmp BYTE [si], 0x00
	je _split_2_end
	mov al, [si]
	mov [di], al
	inc si
	inc di
	jmp _split_2_start

	_split_2_end:
	mov BYTE [di], 0x00

	;move blanks
	_split_mb2_start:
	cmp BYTE [si], 0x20
	je _split_mb2_nb
	jmp _split_mb2_end

	_split_mb2_nb:
	inc si
	jmp _split_mb2_start

	_split_mb2_end:
	mov di, strCmd2

	_split_3_start:			;get third string
	cmp BYTE [si], 0x20
	je _split_3_end
	cmp BYTE [si], 0x00
	je _split_3_end
	mov al, [si]
	mov [di], al
	inc si
	inc di
	jmp _split_3_start

	_split_3_end:
	mov BYTE [di], 0x00

	;move blanks
	_split_mb3_start:
	cmp BYTE [si], 0x20
	je _split_mb3_nb
	jmp _split_mb3_end

	_split_mb3_nb:
	inc si
	jmp _split_mb3_start

	_split_mb3_end:
	mov di, strCmd3

	_split_4_start:			;get fourth string
	cmp BYTE [si], 0x20
	je _split_4_end
	cmp BYTE [si], 0x00
	je _split_4_end
	mov al, [si]
	mov [di], al
	inc si
	inc di
	jmp _split_4_start

	_split_4_end:
	mov BYTE [di], 0x00

	;move blanks
	_split_mb4_start:
	cmp BYTE [si], 0x20
	je _split_mb4_nb
	jmp _split_mb4_end

	_split_mb4_nb:
	inc si
	jmp _split_mb4_start

	_split_mb4_end:
	mov di, strCmd4

	_split_5_start:			;get last string
	cmp BYTE [si], 0x20
	je _split_5_end
	cmp BYTE [si], 0x00
	je _split_5_end
	mov al, [si]
	mov [di], al
	inc si
	inc di
	jmp _split_5_start

	_split_5_end:
	mov BYTE [di], 0x00

	ret

_display_space:
	mov ah, 0x0E                            ; BIOS teletype
	mov al, 0x20
	mov bh, 0x00                            ; display page 0
	mov bl, 0x07                            ; text attribute
	int 0x10                                ; invoke BIOS
	ret

_display_endl:
	mov ah, 0x0E		; BIOS teletype acts on newline!
	mov al, 0x0D
	mov bh, 0x00
	mov bl, 0x07
	int 0x10
	mov ah, 0x0E		; BIOS teletype acts on linefeed!
	mov al, 0x0A
	mov bh, 0x00
	mov bl, 0x07
	int 0x10
	ret

_display_prompt:
	mov si, strPrompt
	mov al, 0x01
	int 0x21
	ret

	;display the string pointed by si
_display:
	mov al, 0x01
	int 0x21
	ret

	;Convert the value of the ax register to decimal and print it
_toDecimal:
	mov si,10
	xor cx,cx

_nonZero:
	xor dx,dx        
	div si       
	push dx               
	inc cx                
	or ax,ax              
	jne _nonZero            

_printDecimal:
	pop dx                  
	add dl,48                
	mov al, dl
	mov ah, 0x0e
	int 0x10
	loop _printDecimal
	ret                      

_otherInfo:
	;# of HDDs
     	xor eax,eax
	mov si, noHarddisk
	call _display
	mov ah, 0x08
	mov dl,0x80
	int 0x13
	xor ax,ax
	mov al,dl
	and al,127
	call _toDecimal
	call _display_endl

	;# of FDDs
	mov si, noFloppy
	call _display	
	int 0x11
	mov bx,ax
	and ax,1
	cmp ax,0 
	je nofloppy	;if no floppy drives available
	mov ax,bx	
	shr ax,6
	and ax,3
	inc ax
	nofloppy:
	call _toDecimal
	endfloppy:
	call _display_endl
	
	;# of Serial Ports
	mov si, serialports
	call _display	
	int 0x11
	and ax,0x0E00
	shr ax,9
	call _toDecimal
	call _display_endl

	;# of Parellel Ports
	mov si,parellelports
	call _display
	int 0x11
	and ax,0xC000
	shr ax,14
	call _toDecimal
	call _display_endl

	;mouse plugged/not plugged
	int 0x33                  
     	cmp ax,0x0000          
     	jz mouseThen          
     	mov si,mUnplug
     	call _display
     	jmp endMouse
    	mouseThen:
     	mov si, mPlug
     	call _display 	
    	endMouse:
	ret

_ram:
	;RAM size
	mov si,ramInf
	call _display
	mov ax, 0xE801
	int 0x15
	mov ax, dx
	shr ax,4
	add ax,16
	call _toDecimal
	mov si,MBlbl
	call _display
	call _display_endl
	ret	

_cpu:
	;CPU Family
	mov si,cpufamily
	call _display
	mov eax, 0x00000001
	cpuid
	and eax,0x00000F00
	shr ax,8
	call _toDecimal
	call _display_endl

	;CPU Model
	mov si,CPUmodelID
	call _display
	mov eax, 0x00000001
	cpuid
	and eax,0x000000F0
	shr ax,4
	call _toDecimal
	call _display_endl
	
	;CPU Stepping
	mov si,cpustepping
	call _display
	mov eax, 0x00000001
	cpuid
	and eax,0x0000000F
	call _toDecimal
	call _display_endl	

	;CPU Vendor
	mov si,cpuVendorID
	call _display
	mov eax,0
	cpuid
	mov [proVenID],ebx
	mov [proVenID+4],edx
	mov [proVenID+8],ecx
	mov si, proVenID
	call _display
	call _display_endl

	mov si,cpuInf
	call _display

	;following 3 blocks gives a description of CPU which include
	;Vendor, Model, Speed
	mov eax,0x80000002
	cpuid
	mov [proInfo],eax
	mov [proInfo+4],ebx
	mov [proInfo+8],ecx
	mov [proInfo+12],edx
	mov si, proInfo
	call _display

	mov eax,0x80000003
	cpuid
	mov [proInfo],eax
	mov [proInfo+4],ebx
	mov [proInfo+8],ecx
	mov [proInfo+12],edx
	mov si, proInfo
	call _display

	mov eax,0x80000004
	cpuid
	mov [proInfo],eax
	mov [proInfo+4],ebx
	mov [proInfo+8],ecx
	mov [proInfo+12],edx
	mov si, proInfo
	call _display
	call _display_endl

	;Get the L2 cache of the processor
	mov eax,0x80000006
	cpuid
	mov si,cacheL2
	call _display
	and ecx,0xFFFF0000
	shr ecx,16
	mov ax,cx
	call _toDecimal
	mov si,kBlbl
	call _display
	call _display_endl
	ret

;End of .text area
[SEGMENT .data]
	strWelcomeMsg   db  "Welcome GC Version 0.05",0x0D,0x0A,"'help' for commands.",0x00
	strPrompt		db	"GC 0.05$ ", 0x00
	cmdMaxLen		db	255			;maximum length of commands

	strOsName		db	"GC ", 0x00		;OS details
	strMajorVer		db	"0", 0x00
	strMinorVer		db	".05", 0x00

	cmdVer			db	"ver", 0x00		; internal commands
	cmdExit			db	"exit", 0x00
	cmdProp			db	"system", 0x00
	cmdHelp			db	"help",0x00

	hTitle		db	"GC Operating System v 0.05 Help info :",0x0D,0x0A,0x00  ;help menu
	hHelp		db	"help    : Show Help menu",0x0D,0x0A,0x00
	hVer			db	"ver     : Show OS Version",0x0D,0x0A,0x00
	hInfo		db	"system  : Show System Hardware Information",0x0D,0x0A,0x00
	helpexit		db	"exit    : Exit the System",0x0D,0x0A,0x00

	txtVersion		db	"version", 0x00	;messages and other strings
	msgUnknownCmd		db	"Unknown command ! type 'help' for details.", 0x00
	decarate			db	"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@",0x0D,0x0A,0x00
	
	propHead		db	"                        System Property Impormations",0x0D,0x0A,0x00
	CPUmodelID		db	"# Processor Model ID   : ",0x00 ;processor details
	cpuInf			db	"# Processor            : ",0x00
	cpufamily		db	"# Processor Family     : ",0x00
	cpustepping		db	"# Processor Stepping   : ",0x00
	cpuVendorID		db	"# Processor Vendor ID  : ",0x00
	
	ramInf			db	"# Ram Size             : ",0x00 ;memory details
	cacheL2			db	"# L2 Cache             : ",0x00
	MBlbl			db	" MB",0x00
	kBlbl			db	" kB",0x00
	
	mPlug			db	"# Mouse is not Plugged",0x0D,0x0A,0x00 ;other hardware info
	mUnplug			db	"# Mouse is Plugged",0x0D,0x0A,0x00
	noFloppy		db	"# No of Floppy Drives  : ",0x00
	noHarddisk		db	"# No of HD Drives      : ",0x00
	serialports		db	"# No of Serial Ports   : ",0x00
	parellelports		db	"# No of Parellel Ports : ",0x00
	
[SEGMENT .bss]
	strUserCmd	resb	256		;buffer for user commands
	cmdChrCnt	resb	1		;count of characters
	strCmd0		resb	256		;buffers for the command components
	strCmd1		resb	256
	strCmd2		resb	256
	strCmd3		resb	256
	strCmd4		resb	256

	proVenID		resd	12	;reserve 12 bytes of memory
	proInfo			resd	16


;********************end of the kernel code********************

