#![no_std]
#![no_main]

use core::arch::global_asm;
use core::panic::PanicInfo;
use core::ptr::write_volatile;

const UART0: *mut u8 = 0x0900_0000 as *mut u8;

#[no_mangle]
pub extern "C" fn kmain() -> ! {
    let msg = b"Hello from Rust\r\n";
    for &c in msg {
        unsafe {
            write_volatile(UART0, c);
        }
    }
    loop {
        unsafe {
            core::arch::asm!("wfe");
        }
    }
}

global_asm!(
    ".section .text.boot",
    ".global _start",
    "_start:",
    "ldr x0, =_stack_top",
    "mov sp, x0",
    "bl kmain",
    "1:",
    "wfe",
    "b 1b",
);

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
