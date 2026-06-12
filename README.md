# zig-metal

A minimal aarch64 bare metal UART bootloader stub, written twice: once in Zig, once in Rust.

## What this is

Two standalone "hello world" stubs that run with no OS, no libc, and no runtime on the QEMU `virt` machine. Each one sets up a stack in an assembly prologue, writes a string to the PL011 UART at `0x09000000`, and parks in an infinite `wfe` loop, so the two toolchains can be compared on the same task.

## Requirements

- QEMU for aarch64: `qemu-system-arm` package (provides `qemu-system-aarch64`)
- Zig 0.13 (the build uses the 0.13 build API)
- Rust with the `aarch64-unknown-none` target and `llvm-objcopy`

Install steps used in this build:

```sh
# QEMU
sudo apt-get install -y qemu-system-arm

# Rust target (core is shipped precompiled, no source build)
rustup target add aarch64-unknown-none

# llvm-objcopy: from llvm-tools, or `cargo install cargo-binutils` for `cargo objcopy`
# This repo's Makefile calls llvm-objcopy directly.
```

Zig needs nothing beyond the `zig` binary itself: the freestanding aarch64 target and the objcopy step are built in.

## Build and run

### Zig

```sh
make zig        # cd zig && zig build  -> zig/zig-out/bin/zig-metal.bin
make run-zig    # qemu-system-aarch64 -M virt -cpu cortex-a57 -nographic -net none -kernel <bin>
```

The target is selected inside `build.zig` (`cpu_arch = .aarch64`, `os_tag = .freestanding`, `abi = .none`), so a plain `zig build` is enough. The equivalent CLI form is `zig build-exe -target aarch64-freestanding-none`. `addObjCopy(.{ .format = .bin })` emits the raw image alongside the ELF.

### Rust

```sh
make rust       # cargo build --release, then llvm-objcopy -O binary -> zig-metal.bin
make run-rust   # same QEMU command against the Rust binary
```

`.cargo/config.toml` pins `target = "aarch64-unknown-none"` and passes `-Tlinker.ld` plus `--gc-sections` to the linker. `cargo build --release` produces an ELF; `llvm-objcopy` turns it into the raw binary. `cargo objcopy` (from `cargo-binutils`) does the same in one step if installed.

### Note on the QEMU command

The run commands add `-net none`. The `virt` machine instantiates a default virtio-net device whose option ROM (`efi-virtio.rom`) lives in the `qemu-system-data` package; `-net none` drops that device so the stub boots without needing any firmware files. Output appears on stdout because `-nographic` wires UART0 to the terminal. Both stubs loop forever, so stop QEMU with `Ctrl-A` then `X`.

## Comparison

All numbers measured on x86_64 Linux (WSL2), cross-compiling to aarch64. Build times are wall clock for a fully clean build (caches removed). Sizes are the raw `.bin` images.

| Dimension          | Zig                                            | Rust                                                       |
|--------------------|------------------------------------------------|------------------------------------------------------------|
| Setup complexity   | Just the `zig` binary; target is built in      | `rustup target add aarch64-unknown-none` plus `llvm-objcopy` |
| Compile time (clean) | ~8.5s                                        | ~0.3s (first cold build ~1.6s)                             |
| Binary size (.bin) | 555 bytes                                      | 164 bytes                                                  |
| Linker script      | `setLinkerScript()` in build.zig; objcopy built in | `-Tlinker.ld` via rustflags; objcopy is a separate step  |
| Overall ergonomics | One file, one command, no external objcopy     | Familiar cargo flow, but target add + objcopy are extra steps |

## Findings

The two toolchains land in different places on the same task. Zig needs zero extra setup, since the freestanding aarch64 target and the objcopy step are part of `zig build`, whereas Rust needs an explicit `rustup target add` and an external `llvm-objcopy` call (or `cargo-binutils`). The clean build times invert that convenience: Zig is ~8.5s because it recompiles its `compiler-rt` support code from source on every clean build, while Rust reuses the precompiled `core` that `rustup` installs, finishing in well under a second. Rust produced the smaller raw image, 164 bytes against Zig's 555, mostly because `--gc-sections` plus `strip` trimmed unused `.rodata` more aggressively than Zig's `ReleaseSmall` did here. Both required the same care in one spot: the `_start` symbol has to sit at offset zero of the raw binary, since QEMU's `-kernel` path jumps straight to the load address, so each version pins it into a `.text.boot` section the linker script places first. Neither is clearly better; Zig trades longer cold builds for a self-contained toolchain, and Rust trades a couple of setup steps for fast incremental builds and a tighter binary.
