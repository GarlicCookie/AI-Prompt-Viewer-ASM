bits 64
default rel

global WinMain
extern GetModuleHandleA, CreateWindowExA, ShowWindow, UpdateWindow, GetMessageA, \
       TranslateMessage, DispatchMessageA, PostQuitMessage, DefWindowProcA, \
       RegisterClassExA, CreateFileA, ReadFile, WriteFile, CloseHandle, MoveWindow, \
       ExitProcess, SetWindowTextA, LoadLibraryA, GetProcAddress, SetFilePointerEx, \
       SendMessageA, OpenClipboard, EmptyClipboard, SetClipboardData, CloseClipboard, \
       GlobalAlloc, GlobalLock, GlobalUnlock, MultiByteToWideChar, BeginPaint, \
       EndPaint, InvalidateRect, GetClientRect

section .data
    className       db "PNGViewerClass", 0
    windowTitle     db "AI Prompt Metadata Viewer", 0
    
    editClassName   db "EDIT", 0
    buttonClassName db "BUTTON", 0
    staticClassName db "STATIC", 0
    fontName        db "Segoe UI", 0

    btnTextBrowse   db "Browse Image...", 0
    btnTextCopy     db "Copy to Clipboard", 0
    btnTextSave     db "Save to .txt", 0

    comdlgDllName   db "comdlg32.dll", 0
    funcGetOpenName db "GetOpenFileNameA", 0
    funcGetSaveName db "GetSaveFileNameA", 0
    
    gdiDllName      db "gdi32.dll", 0
    funcCreateFont  db "CreateFontA", 0

    shellDllName    db "shell32.dll", 0
    funcDragAccept  db "DragAcceptFiles", 0
    funcDragQuery   db "DragQueryFileA", 0
    funcDragFinish  db "DragFinish", 0

    gdiplusDllName      db "gdiplus.dll", 0
    funcGdiplusStartup  db "GdiplusStartup", 0
    funcGdiplusShutdown db "GdiplusShutdown", 0
    funcGdipLoadImage   db "GdipLoadImageFromFile", 0
    funcGdipDispose     db "GdipDisposeImage", 0
    funcGdipCreateFrom  db "GdipCreateFromHDC", 0
    funcGdipDeleteG     db "GdipDeleteGraphics", 0
    funcGdipDrawImage   db "GdipDrawImageRectI", 0
    funcGdipGetW        db "GdipGetImageWidth", 0
    funcGdipGetH        db "GdipGetImageHeight", 0

    gdiplusStartupInput dd 1, 0, 0, 0, 0, 0

    ofnFilter       db "PNG Files (*.png)", 0, "*.png", 0, "All Files (*.*)", 0, "*.*", 0, 0
    ofnTitle        db "Select AI Generated PNG Image", 0
    saveFilter      db "Text Files (*.txt)", 0, "*.txt", 0, 0, 0
    saveTitle       db "Save Prompt Data", 0
    defTxtExt       db "txt", 0

    png_signature   db 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
    text_chunk_type db "tEXt"
    
    ; --- ENGINE KEYS ---
    key_a1111       db "parameters", 0
    key_comfy       db "prompt", 0
    key_invoke      db "invokeai_metadata", 0
    key_novelai     db "Description", 0

    ; --- UI LABELS ---
    lbl_a1111       db "Engine Detected: Automatic1111", 0
    lbl_comfy       db "Engine Detected: ComfyUI", 0
    lbl_invoke      db "Engine Detected: InvokeAI", 0
    lbl_novelai     db "Engine Detected: NovelAI", 0
    lbl_default     db "Engine Detected: None", 0

    msg_default     db "Drag & Drop a PNG file here, or click 'Browse Image...'", 0
    msg_no_meta     db "No Automatic1111, ComfyUI, InvokeAI, or NovelAI metadata found.", 0
    msg_bad_png     db "Error: Selected file is not a valid PNG image.", 0
    msg_file_err    db "Error: Failed to open file.", 0

section .bss
    hInstance       resq 1
    hWndMain        resq 1
    hWndEdit        resq 1
    hWndBtnBrowse   resq 1
    hWndBtnCopy     resq 1
    hWndBtnSave     resq 1
    hWndLabel       resq 1
    
    pGetOpenFileName resq 1
    pGetSaveFileName resq 1
    pCreateFont      resq 1
    pDragAcceptFiles resq 1
    pDragQueryFileA  resq 1
    pDragFinish      resq 1
    
    pGdiplusStartup  resq 1
    pGdiplusShutdown resq 1
    pGdipLoadImage   resq 1
    pGdipDispose     resq 1
    pGdipCreateFrom  resq 1
    pGdipDeleteG     resq 1
    pGdipDrawImage   resq 1
    pGdipGetW        resq 1
    pGdipGetH        resq 1

    hFont            resq 1
    fileHandle      resq 1
    bytesRead       resd 1
    chunkLen        resd 1
    
    gdiplusToken     resq 1
    hImage           resq 1
    imgWidth         resd 1
    imgHeight        resd 1
    
    filePath        resb 512
    wideFilePath    resb 1024           
    ofn             resb 152            
    headerBuf       resb 8              
    payloadBuf      resb 1048576        
    formattedBuf    resb 2097152        

section .text

WinMain:
    push rbp
    mov rbp, rsp
    sub rsp, 144

    lea rcx, [comdlgDllName]
    call LoadLibraryA
    mov rbx, rax
    mov rcx, rbx
    lea rdx, [funcGetOpenName]
    call GetProcAddress
    mov [pGetOpenFileName], rax
    mov rcx, rbx
    lea rdx, [funcGetSaveName]
    call GetProcAddress
    mov [pGetSaveFileName], rax

    lea rcx, [gdiDllName]
    call LoadLibraryA
    mov rcx, rax
    lea rdx, [funcCreateFont]
    call GetProcAddress
    mov [pCreateFont], rax

    lea rcx, [shellDllName]
    call LoadLibraryA
    mov rbx, rax
    mov rcx, rbx
    lea rdx, [funcDragAccept]
    call GetProcAddress
    mov [pDragAcceptFiles], rax
    mov rcx, rbx
    lea rdx, [funcDragQuery]
    call GetProcAddress
    mov [pDragQueryFileA], rax
    mov rcx, rbx
    lea rdx, [funcDragFinish]
    call GetProcAddress
    mov [pDragFinish], rax

    lea rcx, [gdiplusDllName]
    call LoadLibraryA
    mov rbx, rax
    mov rcx, rbx
    lea rdx, [funcGdiplusStartup]
    call GetProcAddress
    mov [pGdiplusStartup], rax
    mov rcx, rbx
    lea rdx, [funcGdiplusShutdown]
    call GetProcAddress
    mov [pGdiplusShutdown], rax
    mov rcx, rbx
    lea rdx, [funcGdipLoadImage]
    call GetProcAddress
    mov [pGdipLoadImage], rax
    mov rcx, rbx
    lea rdx, [funcGdipDispose]
    call GetProcAddress
    mov [pGdipDispose], rax
    mov rcx, rbx
    lea rdx, [funcGdipCreateFrom]
    call GetProcAddress
    mov [pGdipCreateFrom], rax
    mov rcx, rbx
    lea rdx, [funcGdipDeleteG]
    call GetProcAddress
    mov [pGdipDeleteG], rax
    mov rcx, rbx
    lea rdx, [funcGdipDrawImage]
    call GetProcAddress
    mov [pGdipDrawImage], rax
    mov rcx, rbx
    lea rdx, [funcGdipGetW]
    call GetProcAddress
    mov [pGdipGetW], rax
    mov rcx, rbx
    lea rdx, [funcGdipGetH]
    call GetProcAddress
    mov [pGdipGetH], rax

    lea rcx, [gdiplusToken]
    lea rdx, [gdiplusStartupInput]
    xor r8, r8
    call [pGdiplusStartup]

    mov ecx, -15                    
    xor rdx, rdx                    
    xor r8, r8                      
    xor r9, r9                      
    mov dword [rsp + 32], 400       
    mov dword [rsp + 40], 0         
    mov dword [rsp + 48], 0         
    mov dword [rsp + 56], 0         
    mov dword [rsp + 64], 1         
    mov dword [rsp + 72], 0         
    mov dword [rsp + 80], 0         
    mov dword [rsp + 88], 5         
    mov dword [rsp + 96], 0         
    lea rax, [fontName]
    mov [rsp + 104], rax            
    call [pCreateFont]
    mov [hFont], rax

    xor rcx, rcx
    call GetModuleHandleA
    mov [hInstance], rax

    mov dword [rsp + 32], 80
    mov dword [rsp + 36], 3
    lea rax, [WndProc]
    mov [rsp + 40], rax
    mov dword [rsp + 48], 0
    mov dword [rsp + 52], 0
    mov rax, [hInstance]
    mov [rsp + 56], rax
    mov qword [rsp + 64], 0
    mov qword [rsp + 72], 0
    mov qword [rsp + 80], 16        
    mov qword [rsp + 88], 0
    lea rax, [className]
    mov [rsp + 96], rax
    mov qword [rsp + 104], 0

    lea rcx, [rsp + 32]
    call RegisterClassExA

    mov qword [rsp + 88], 0
    mov rax, [hInstance]
    mov [rsp + 80], rax
    mov qword [rsp + 72], 0
    mov qword [rsp + 64], 0
    mov dword [rsp + 56], 700       
    mov dword [rsp + 48], 1100      
    mov dword [rsp + 40], 0x80000000
    mov dword [rsp + 32], 0x80000000
    mov r9d, 0x00CF0000
    lea r8, [windowTitle]
    lea rdx, [className]
    xor rcx, rcx
    call CreateWindowExA
    mov [hWndMain], rax

    mov rcx, [hWndMain]
    mov rdx, 5
    call ShowWindow
    mov rcx, [hWndMain]
    call UpdateWindow

.msg_loop:
    lea rcx, [rsp + 32]
    xor rdx, rdx
    xor r8, r8
    xor r9, r9
    call GetMessageA
    test eax, eax
    jz .exit
    lea rcx, [rsp + 32]
    call TranslateMessage
    lea rcx, [rsp + 32]
    call DispatchMessageA
    jmp .msg_loop

.exit:
    cmp qword [hImage], 0
    je .no_img
    mov rcx, [hImage]
    call [pGdipDispose]
.no_img:
    mov rcx, [gdiplusToken]
    call [pGdiplusShutdown]
    mov ecx, 0
    call ExitProcess

; -------------------------------------------------------------------------
; WINDOW PROCEDURE
; -------------------------------------------------------------------------
WndProc:
    push rbp
    mov rbp, rsp
    push rbx
    push rdi
    push rsi
    push r12
    push r13
    push r14
    push r15
    sub rsp, 136                    

    mov [rbp + 16], rcx
    mov [rbp + 24], rdx
    mov [rbp + 32], r8
    mov [rbp + 40], r9

    cmp edx, 1
    je .on_create
    cmp edx, 5
    je .on_size
    cmp edx, 15
    je .on_paint
    cmp edx, 273
    je .on_command
    cmp edx, 563
    je .on_dropfiles
    cmp edx, 2
    je .on_destroy
    jmp .def_proc

.on_create:
    mov rcx, [rbp + 16]
    mov rdx, 1
    call [pDragAcceptFiles]

    mov qword [rsp + 88], 0
    mov rax, [hInstance]
    mov [rsp + 80], rax
    mov qword [rsp + 72], 1001
    mov rax, [rbp + 16]         
    mov [rsp + 64], rax
    mov dword [rsp + 56], 35        
    mov dword [rsp + 48], 150       
    mov dword [rsp + 40], 20        
    mov dword [rsp + 32], 20        
    mov r9d, 0x50000000
    lea r8, [btnTextBrowse]
    lea rdx, [buttonClassName]
    xor rcx, rcx
    call CreateWindowExA
    mov [hWndBtnBrowse], rax

    mov qword [rsp + 88], 0
    mov rax, [hInstance]
    mov [rsp + 80], rax
    mov qword [rsp + 72], 1004
    mov rax, [rbp + 16]         
    mov [rsp + 64], rax
    mov dword [rsp + 56], 35        
    mov dword [rsp + 48], 150       
    mov dword [rsp + 40], 20        
    mov dword [rsp + 32], 180       
    mov r9d, 0x50000000
    lea r8, [btnTextCopy]
    lea rdx, [buttonClassName]
    xor rcx, rcx
    call CreateWindowExA
    mov [hWndBtnCopy], rax

    mov qword [rsp + 88], 0
    mov rax, [hInstance]
    mov [rsp + 80], rax
    mov qword [rsp + 72], 1005
    mov rax, [rbp + 16]         
    mov [rsp + 64], rax
    mov dword [rsp + 56], 35        
    mov dword [rsp + 48], 120       
    mov dword [rsp + 40], 20        
    mov dword [rsp + 32], 340       
    mov r9d, 0x50000000
    lea r8, [btnTextSave]
    lea rdx, [buttonClassName]
    xor rcx, rcx
    call CreateWindowExA
    mov [hWndBtnSave], rax

    mov qword [rsp + 88], 0
    mov rax, [hInstance]
    mov [rsp + 80], rax
    mov qword [rsp + 72], 1003
    mov rax, [rbp + 16]
    mov [rsp + 64], rax
    mov dword [rsp + 56], 25        
    mov dword [rsp + 48], 280       
    mov dword [rsp + 40], 28        
    mov dword [rsp + 32], 475       
    mov r9d, 0x50000000             
    lea r8, [lbl_default]
    lea rdx, [staticClassName]
    xor rcx, rcx
    call CreateWindowExA
    mov [hWndLabel], rax

    mov qword [rsp + 88], 0
    mov rax, [hInstance]
    mov [rsp + 80], rax
    mov qword [rsp + 72], 1002  
    mov rax, [rbp + 16]
    mov [rsp + 64], rax
    mov dword [rsp + 56], 470       
    mov dword [rsp + 48], 500       
    mov dword [rsp + 40], 70        
    mov dword [rsp + 32], 550       
    mov r9d, 0x50200844             
    lea r8, [msg_default]
    lea rdx, [editClassName]
    mov rcx, 0x00000200             
    call CreateWindowExA
    mov [hWndEdit], rax
    
    mov rdx, 0x30                   
    mov r8, [hFont]
    mov r9, 1 
    mov rcx, [hWndBtnBrowse]                      
    call SendMessageA
    mov rdx, 0x30
    mov r8, [hFont]
    mov r9, 1 
    mov rcx, [hWndBtnCopy]                      
    call SendMessageA
    mov rdx, 0x30
    mov r8, [hFont]
    mov r9, 1 
    mov rcx, [hWndBtnSave]                      
    call SendMessageA
    mov rdx, 0x30
    mov r8, [hFont]
    mov r9, 1 
    mov rcx, [hWndLabel]                      
    call SendMessageA
    mov rdx, 0x30
    mov r8, [hFont]
    mov r9, 1 
    mov rcx, [hWndEdit]                      
    call SendMessageA

    xor eax, eax
    jmp .finish

.on_size:
    cmp qword [hWndEdit], 0
    je .def_proc

    mov eax, [rbp + 40]
    movzx r11d, ax              
    shr eax, 16
    movzx r10d, ax              

    mov eax, r11d
    sar eax, 1                  
    mov r9d, eax                
    sub r9d, 15
    mov edx, eax                
    add edx, 5
    mov r8d, 70                 
    mov eax, r10d
    sub eax, 90                 
    mov [rsp + 32], eax

    mov qword [rsp + 40], 1     
    mov rcx, [hWndEdit]         
    call MoveWindow
    
    mov rcx, [hWndMain]
    xor rdx, rdx
    mov r8d, 1
    call InvalidateRect

    xor eax, eax
    jmp .finish

.on_paint:
    mov rcx, [rbp + 16]
    lea rdx, [rsp + 32]         
    call BeginPaint
    mov r12, rax                

    cmp qword [hImage], 0
    je .paint_end
    
    cmp dword [imgWidth], 0
    je .paint_end
    cmp dword [imgHeight], 0
    je .paint_end

    mov rcx, [rbp + 16]
    lea rdx, [rsp + 104]        
    call GetClientRect

    mov r13d, dword [rsp + 112] 
    sar r13d, 1
    sub r13d, 25                
    mov r14d, dword [rsp + 116] 
    sub r14d, 90                

    mov rcx, r12
    lea rdx, [rsp + 120]        
    call [pGdipCreateFrom]

    mov eax, r13d
    mov ecx, 10000
    mul ecx
    div dword [imgWidth]
    mov ebx, eax                

    mov eax, r14d
    mov ecx, 10000
    mul ecx
    div dword [imgHeight]       

    cmp ebx, eax
    cmovl eax, ebx              
    mov ebx, eax                

    mov eax, dword [imgWidth]
    mul ebx
    mov ecx, 10000
    div ecx
    mov r15d, eax               

    mov eax, dword [imgHeight]
    mul ebx
    mov ecx, 10000
    div ecx                     
    mov dword [rsp + 128], eax  

    mov eax, r13d
    sub eax, r15d
    sar eax, 1
    add eax, 20
    mov r8d, eax                

    mov eax, r14d
    sub eax, dword [rsp + 128]
    sar eax, 1
    add eax, 70
    mov r9d, eax                

    mov rcx, qword [rsp + 120]  
    mov rdx, [hImage]           
    mov dword [rsp + 32], r15d  
    mov eax, dword [rsp + 128]
    mov dword [rsp + 40], eax   
    call [pGdipDrawImage]

    mov rcx, qword [rsp + 120]
    call [pGdipDeleteG]

.paint_end:
    mov rcx, [rbp + 16]
    lea rdx, [rsp + 32]
    call EndPaint

    xor eax, eax
    jmp .finish

.on_dropfiles:
    mov rcx, [rbp + 32]         
    mov rdx, 0                  
    lea r8, [filePath]
    mov r9, 512
    call [pDragQueryFileA]

    mov rcx, [rbp + 32]
    call [pDragFinish]

    call ParseImage             
    xor eax, eax
    jmp .finish

.on_command:
    mov rax, [rbp + 32]
    movzx eax, ax
    
    cmp eax, 1001
    je .cmd_browse
    cmp eax, 1004
    je .cmd_copy
    cmp eax, 1005
    je .cmd_save
    jne .def_proc

.cmd_browse:
    call BrowseAndParse
    xor eax, eax
    jmp .finish

.cmd_copy:
    call CopyToClipboard
    xor eax, eax
    jmp .finish

.cmd_save:
    call SaveToFile
    xor eax, eax
    jmp .finish

.on_destroy:
    xor rcx, rcx
    call PostQuitMessage
    xor eax, eax
    jmp .finish

.def_proc:
    mov rcx, [rbp + 16]
    mov rdx, [rbp + 24]
    mov r8,  [rbp + 32]
    mov r9,  [rbp + 40]
    call DefWindowProcA

.finish:
    add rsp, 136
    pop r15
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rbx
    pop rbp
    ret


; -------------------------------------------------------------------------
; FILE BROWSING 
; -------------------------------------------------------------------------
BrowseAndParse:
    push rbp
    mov rbp, rsp
    push rbx
    push rdi
    sub rsp, 144

    lea r10, [ofn]
    mov rcx, 19
    xor rax, rax
.clear_ofn:
    mov [r10], rax
    add r10, 8
    loop .clear_ofn

    lea r10, [filePath]
    mov byte [r10], 0

    lea rbx, [ofn]
    mov dword [rbx + 0], 152
    mov rax, [hWndMain]
    mov [rbx + 8], rax
    lea rax, [ofnFilter]
    mov [rbx + 24], rax
    lea rax, [filePath]
    mov [rbx + 48], rax
    mov dword [rbx + 56], 512
    lea rax, [ofnTitle]
    mov [rbx + 88], rax
    mov dword [rbx + 96], 0x00000800

    lea rcx, [ofn]
    call [pGetOpenFileName]
    test eax, eax
    jz .done

    call ParseImage

.done:
    add rsp, 144
    pop rdi
    pop rbx
    pop rbp
    ret


; -------------------------------------------------------------------------
; CORE PNG LOGIC & IMAGE RENDERING
; -------------------------------------------------------------------------
ParseImage:
    push rbp
    mov rbp, rsp
    push rbx
    push rdi
    sub rsp, 144

    xor rcx, rcx                
    xor rdx, rdx                
    lea r8, [filePath]          
    mov r9, -1                  
    lea rax, [wideFilePath]
    mov [rsp + 32], rax
    mov dword [rsp + 40], 512
    call MultiByteToWideChar

    cmp qword [hImage], 0
    je .load_new_img
    mov rcx, [hImage]
    call [pGdipDispose]
    mov qword [hImage], 0       
.load_new_img:
    lea rcx, [wideFilePath]
    lea rdx, [hImage]
    call [pGdipLoadImage]

    mov rcx, [hImage]
    lea rdx, [imgWidth]
    call [pGdipGetW]
    mov rcx, [hImage]
    lea rdx, [imgHeight]
    call [pGdipGetH]

    mov rcx, [hWndMain]
    xor rdx, rdx
    mov r8d, 1
    call InvalidateRect

    mov qword [rsp + 48], 0
    mov dword [rsp + 40], 0x80
    mov dword [rsp + 32], 3
    xor r9, r9
    mov r8d, 1
    mov edx, 0x80000000
    lea rcx, [filePath]
    call CreateFileA
    mov [fileHandle], rax
    cmp rax, -1
    je .err_file

    mov qword [rsp + 32], 0
    lea r9, [bytesRead]
    mov r8d, 8
    lea rdx, [headerBuf]
    mov rcx, [fileHandle]
    call ReadFile

    lea r10, [headerBuf]
    lea r11, [png_signature]
    mov rcx, 8
.chk_sig:
    mov al, [r10]
    mov dl, [r11]
    cmp al, dl
    jne .err_png
    inc r10
    inc r11
    loop .chk_sig

.read_chunk:
    mov qword [rsp + 32], 0
    lea r9, [bytesRead]
    mov r8d, 8
    lea rdx, [headerBuf]
    mov rcx, [fileHandle]
    call ReadFile
    cmp dword [bytesRead], 8
    jne .err_nometa

    mov eax, dword [headerBuf]
    bswap eax
    mov [chunkLen], eax

    mov eax, dword [headerBuf + 4]
    cmp eax, dword [text_chunk_type]
    je .process_text

.skip_chunk:
    mov rcx, [fileHandle]
    mov edx, [chunkLen]
    add rdx, 4
    xor r8, r8
    mov r9d, 1
    call SetFilePointerEx
    jmp .read_chunk

.process_text:
    cmp dword [chunkLen], 1000000
    jg .skip_chunk

    mov qword [rsp + 32], 0
    lea r9, [bytesRead]
    mov r8d, [chunkLen]
    lea rdx, [payloadBuf]
    mov rcx, [fileHandle]
    call ReadFile

    lea r10, [payloadBuf]
    mov ecx, [chunkLen]
    mov byte [r10 + rcx], 0
    
.try_a1111:
    lea r10, [payloadBuf]
    lea r11, [key_a1111]
    mov rcx, 11
.chk_a1111:
    mov al, [r10]
    mov dl, [r11]
    cmp al, dl
    jne .try_comfy
    inc r10
    inc r11
    loop .chk_a1111
    mov rbx, 11
    lea rdi, [lbl_a1111]
    jmp .display_success

.try_comfy:
    lea r10, [payloadBuf]
    lea r11, [key_comfy]
    mov rcx, 7
.chk_comfy:
    mov al, [r10]
    mov dl, [r11]
    cmp al, dl
    jne .try_invoke
    inc r10
    inc r11
    loop .chk_comfy
    mov rbx, 7
    lea rdi, [lbl_comfy]
    jmp .display_success

.try_invoke:
    lea r10, [payloadBuf]
    lea r11, [key_invoke]
    mov rcx, 18
.chk_invoke:
    mov al, [r10]
    mov dl, [r11]
    cmp al, dl
    jne .try_novelai           ; Jumps to NovelAI if Invoke fails
    inc r10
    inc r11
    loop .chk_invoke
    mov rbx, 18
    lea rdi, [lbl_invoke]
    jmp .display_success

.try_novelai:
    lea r10, [payloadBuf]
    lea r11, [key_novelai]
    mov rcx, 11
.chk_novelai:
    mov al, [r10]
    mov dl, [r11]
    cmp al, dl
    jne .not_params
    inc r10
    inc r11
    loop .chk_novelai
    mov rbx, 11
    lea rdi, [lbl_novelai]
    jmp .display_success

.display_success:
    mov rcx, [hWndLabel]
    mov rdx, rdi
    call SetWindowTextA

    lea rcx, [payloadBuf]
    add rcx, rbx                    
    lea rdx, [formattedBuf]
    call FormatMetadata

    mov rcx, [hWndEdit]
    lea rdx, [formattedBuf]
    call SetWindowTextA
    
    jmp .close_file

.not_params:
    mov rcx, [fileHandle]
    mov rdx, 4                      
    xor r8, r8
    mov r9d, 1
    call SetFilePointerEx
    jmp .read_chunk

.err_png:
    mov rcx, [hWndEdit]
    lea rdx, [msg_bad_png]
    call SetWindowTextA
    mov byte [formattedBuf], 0
    jmp .reset_lbl_and_close

.err_file:
    mov rcx, [hWndEdit]
    lea rdx, [msg_file_err]
    call SetWindowTextA
    mov byte [formattedBuf], 0
    jmp .reset_lbl_and_close

.err_nometa:
    mov rcx, [hWndEdit]
    lea rdx, [msg_no_meta]
    call SetWindowTextA
    mov byte [formattedBuf], 0

.reset_lbl_and_close:
    mov rcx, [hWndLabel]
    lea rdx, [lbl_default]
    call SetWindowTextA

.close_file:
    mov rcx, [fileHandle]
    call CloseHandle

.done:
    add rsp, 144
    pop rdi
    pop rbx
    pop rbp
    ret


; -------------------------------------------------------------------------
; FEATURE: COPY TO CLIPBOARD
; -------------------------------------------------------------------------
CopyToClipboard:
    push rbp
    mov rbp, rsp
    push rbx
    push rdi
    push rsi
    sub rsp, 136

    lea rax, [formattedBuf]
.len_loop:
    cmp byte [rax], 0
    je .len_done
    inc rax
    jmp .len_loop
.len_done:
    lea rcx, [formattedBuf]
    sub rax, rcx
    test rax, rax
    jz .done                        
    inc rax                         

    mov rcx, 0x0002
    mov rdx, rax
    call GlobalAlloc
    test rax, rax
    jz .done
    mov rbx, rax                    

    mov rcx, rbx
    call GlobalLock
    mov rdi, rax                    
    lea rsi, [formattedBuf]         

.copy_loop:
    mov cl, [rsi]
    mov [rdi], cl
    test cl, cl
    jz .copy_done
    inc rsi
    inc rdi
    jmp .copy_loop
.copy_done:
    mov rcx, rbx
    call GlobalUnlock

    mov rcx, [hWndMain]
    call OpenClipboard
    call EmptyClipboard
    mov rcx, 1                      
    mov rdx, rbx
    call SetClipboardData
    call CloseClipboard

.done:
    add rsp, 136
    pop rsi
    pop rdi
    pop rbx
    pop rbp
    ret


; -------------------------------------------------------------------------
; FEATURE: SAVE TO TXT
; -------------------------------------------------------------------------
SaveToFile:
    push rbp
    mov rbp, rsp
    push rbx
    push rdi
    sub rsp, 144

    cmp byte [formattedBuf], 0
    je .done

    lea r10, [ofn]
    mov rcx, 19
    xor rax, rax
.clear_ofn:
    mov [r10], rax
    add r10, 8
    loop .clear_ofn

    lea r10, [filePath]
    mov byte [r10], 0

    lea rbx, [ofn]
    mov dword [rbx + 0], 152
    mov rax, [hWndMain]
    mov [rbx + 8], rax
    lea rax, [saveFilter]
    mov [rbx + 24], rax
    lea rax, [filePath]
    mov [rbx + 48], rax
    mov dword [rbx + 56], 512
    lea rax, [saveTitle]
    mov [rbx + 88], rax
    mov dword [rbx + 96], 0x00000002 
    lea rax, [defTxtExt]
    mov [rbx + 104], rax             

    lea rcx, [ofn]
    call [pGetSaveFileName]
    test eax, eax
    jz .done

    mov qword [rsp + 48], 0
    mov dword [rsp + 40], 0x80
    mov dword [rsp + 32], 2
    xor r9, r9
    mov r8d, 0
    mov edx, 0x40000000              
    lea rcx, [filePath]
    call CreateFileA
    mov [fileHandle], rax
    cmp rax, -1
    je .done

    lea rax, [formattedBuf]
.len_loop:
    cmp byte [rax], 0
    je .len_done
    inc rax
    jmp .len_loop
.len_done:
    lea rcx, [formattedBuf]
    sub rax, rcx                     
    
    mov qword [rsp + 32], 0
    lea r9, [bytesRead]
    mov r8d, eax
    lea rdx, [formattedBuf]
    mov rcx, [fileHandle]
    call WriteFile

    mov rcx, [fileHandle]
    call CloseHandle

.done:
    add rsp, 144
    pop rdi
    pop rbx
    pop rbp
    ret


; -------------------------------------------------------------------------
; PRETTY PRINTER 
; -------------------------------------------------------------------------
FormatMetadata:
    mov r10, rcx
    mov r11, rdx
    xor r8, r8                      

    cmp byte [r10], '{'
    je .json_mode

.a1111_mode:
    mov al, [r10]
    test al, al
    jz .done_format

    cmp al, 0x0A                    
    jne .write_a1111
    mov byte [r11], 0x0D            
    inc r11
.write_a1111:
    mov [r11], al
    inc r11
    inc r10
    jmp .a1111_mode

.json_mode:
    mov al, [r10]
    test al, al
    jz .done_format

    cmp al, '"'
    jne .write_json
    xor r8, 1                       
.write_json:
    mov [r11], al
    inc r11
    inc r10

    test r8, r8
    jnz .json_mode                  

    cmp al, '{'
    je .insert_crlf
    cmp al, '}'
    je .insert_crlf
    cmp al, ','
    je .insert_crlf
    jmp .json_mode

.insert_crlf:
    mov byte [r11], 0x0D            
    inc r11
    mov byte [r11], 0x0A            
    inc r11
    jmp .json_mode

.done_format:
    mov byte [r11], 0               
    ret