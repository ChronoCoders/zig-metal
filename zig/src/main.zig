const UART0: *volatile u8 = @ptrFromInt(0x09000000);

export fn kmain() noreturn {
    const msg = "Hello from Zig\r\n";
    for (msg) |c| {
        UART0.* = c;
    }
    while (true) {
        asm volatile ("wfe");
    }
}

export fn _start() linksection(".text.boot") callconv(.Naked) noreturn {
    asm volatile (
        \\ldr x0, =_stack_top
        \\mov sp, x0
        \\bl kmain
        \\1:
        \\wfe
        \\b 1b
    );
}
