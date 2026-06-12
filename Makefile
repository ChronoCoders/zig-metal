QEMU ?= qemu-system-aarch64
QEMU_FLAGS = -M virt -cpu cortex-a57 -nographic -net none
OBJCOPY ?= llvm-objcopy

ZIG_BIN = zig/zig-out/bin/zig-metal.bin
RUST_ELF = rust/target/aarch64-unknown-none/release/zig-metal
RUST_BIN = rust/target/aarch64-unknown-none/release/zig-metal.bin

.PHONY: all zig rust run-zig run-rust clean

all: zig rust

zig:
	cd zig && zig build

rust:
	cd rust && cargo build --release
	$(OBJCOPY) -O binary $(RUST_ELF) $(RUST_BIN)

run-zig: zig
	$(QEMU) $(QEMU_FLAGS) -kernel $(ZIG_BIN)

run-rust: rust
	$(QEMU) $(QEMU_FLAGS) -kernel $(RUST_BIN)

clean:
	rm -rf zig/zig-out zig/.zig-cache rust/target
