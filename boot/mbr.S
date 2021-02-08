;主引导程序
;-------------------------------------------
%include "boot.inc"
SECTION MBR vstart=0x7c00
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov sp, 0x7c00
    mov ax, 0xb800
    mov gs, ax

; 清屏 利用0x06号功能，上卷全部行，则可清屏
;-----------------------------------------------
;int 0x10  功能号：0x06       功能描述：上卷窗口
;------------------------------------------------
;输入：
;AH 功能号= 0x06
;AL = 上卷的行数（如果为0，表示全部）
;BH = 上卷属性
;(CL,CH) = 窗口左上角的（X,Y）位置
;(DL,DH) = 窗口右下角的（X,Y）位置
;无返回值
    mov  ax,  0x600
    mov  bx,  0x700
    mov  cx,  0         ;左上角：（0, 0）
    mov  dx,  0x184f    ;右上角  （80，25）
                    ; VGA文本模式中,一行只能容纳80个字符,共25行。
                    ; 下标从0开始,所以0x18=24,0x4f=79
    int 0x10
;;;;;;;;;    下面这三行代码是获取光标位置    ;;;;;;;;;
;.get_cursor获取当前光标位置,在光标位置处打印字符.
   mov ah, 3		; 输入: 3号子功能是获取光标位置,需要存入ah寄存器
   mov bh, 0		; bh寄存器存储的是待获取光标的页号

   int 0x10		    ; 输出: ch=光标开始行,cl=光标结束行
			        ; dh=光标所在行号,dl=光标所在列号

;;;;;;;;;    获取光标位置结束    ;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;; 打印字符串  ;;;;;;;;;;;;;;;;;;;;;;;
;-------------------------------------------------
; 还是 0x10 号中断，不过这次是调用13号子功能
;------------------------------------------------
    mov ax,  msg1
    mov bp,  ax
    mov cx,  5          ; cx 为字符串长度，不包括结束符
    mov ax,  0x1301     ; 子功能号13是显示字符及属性,要存入ah寄存器
                        ; al设置写字符方式 显示字符串,光标跟随移动
    mov bx, 0x2         ; bh存储要显示的页号,此处是第0页,
			            ; bl中是字符属性, 属性黑底绿字(bl = 02h)
    int 0x10
;;;;;;;;;;;;;;;;; 打印字符串结束  ;;;;;;;;;;;;;;;;;;

    mov eax, LOADER_START_SECTOR        ; 起始扇区lba地址
    mov bx,  LOADER_BASE_ADDR           ; 写入的地址
    mov cx,  4                          ; 写入的扇区数
    call  rd_disk_m_16                  ; 读取磁盘loader程序
    jmp LOADER_BASE_ADDR + 0x300

;--------------------------------------------------------------
;功能:读取硬盘n个扇区
; eax=LBA扇区号
; ebx=将数据写入的内存地址
; ecx=读入的扇区数
rd_disk_m_16:
;--------------------------------------------------------------
    mov esi,  eax       ;备份eax
    mov di,   cx        ;备份cx

;读取硬盘
;第一步：设置要读取的扇区数
    mov dx, 0x1f2
    mov al, cl
    out dx, al

    mov eax, esi    ;恢复ax

;第二步：将LBA地址存入 0x1f3 ~ 0x1f6

;将LBA地址 0~7 位写入端口 0x1f3
    mov dx, 0x1f3
    out dx, al

;LBA地址 8~15 位 写入端口 0x1f4
    mov cl, 8
    shr eax, cl
    mov dx, 0x1f4
    out dx, al

;LBA地址 16~23 位写入端口 0x1f5
    shr eax, cl
    mov dx, 0x1f5
    out dx, al

    shr eax, cl
    and al, 0x0f    ;LBA第24~27位
    or al, 0xe0     ;设置7-4位为1110，表示lba模式
    mov dx, 0x1f6
    out dx, al

;第三步：向0x1f7端口写入读命令：0x20
    mov dx, 0x1f7
    mov al, 0x20
    out dx, al

;第四步：检查硬盘状态
.not_ready:
    ;同一端口，写时表示写入命令字，读时表示读入硬盘状态
    nop
    in al, dx
    and al, 0x88     ;第3位为1表示硬盘控制器已准备好数据传输，第7位为1表示硬盘忙
    cmp al, 0x08
    jnz .not_ready      ;若为准备好，继续等

;第五步：从0x1f0端口读数据
    mov ax, di
    mov dx, 256
    mul dx
    mov cx, ax      ; di为要读取的扇区数，一个扇区有512字节，每次读入一个字，
                    ; 共需di*512/2次，所以di*256
    mov dx, 0x1f0

.go_on_read:
    in ax, dx
    mov [bx], ax
    add bx, 2
    loop .go_on_read
    ret


msg1 db "1 MBR"
times 510-($-$$) db 0
db 0x55,0xaa
