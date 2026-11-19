# newminhh (`新明` — "New Tomorrow")

**Container-less i386 (`ELFCLASS32`, `EM_386`) Compatibility System for x32-Only (`ELFCLASS32`, `EM_X86_64`, ILP32) Linux.**

> **Visitor Entrypoint:** Start at **[`newminhh/docs`](https://github.com/newminhh/docs)** for the project overview, architecture reference, and VM/testing guides.
>
> **Original Goal & Inspiration:** **"Better capability, less RAM usage guaranteed"** — inspired by [*Janet on x32: 32-bit Pointers, 64-bit Speed, 25% Less RAM*](https://alexalejandre.com/programming/lisp/janet-for-the-x32-abi), keeping full 64-bit Long Mode register speed and 32-bit pointer RAM efficiency in a pure `x32` userspace while running legacy `i386` binaries and `.so` libraries against shared native `x32` system libraries.
>
> **Meaning Behind the Name:** **`newminhh`** is named after **Tân Minh** commune (Hải Phòng, Vietnam), the author's home commune—translating to **"New Tomorrow"** in English and **新明** (*Xīn Míng*) in Simplified Chinese.

`newminhh` runs unmodified 32-bit x86 Linux executables and shared libraries (`.so`) directly on a pure x32 Linux userspace whose kernel runs with `ia32_emulation=0` and `syscall.x32=y`—requiring zero `:i386` packages, zero `libc6-i386`, and zero `/lib/ld-linux.so.2`, while keeping native x32 shared libraries (`libc.so.6`, `libm.so.6`, `libnewminhh_compat.so`) page-cache shared across processes.

---

## Split Repository Map (`https://github.com/newminhh`)

This umbrella repository (`newminhh/newminhh`) provides top-level build orchestration (`Makefile`), unified CLI (`bin/newminhh`), Debian x32 VM provisioning (`vm/`), and the 5-part verification & `/proc/<pid>/smaps` benchmarking suites (`tests/`). The core subsystems live in dedicated repositories under [`https://github.com/newminhh`](https://github.com/newminhh):

| Repository | Local Path | Role |
| :--- | :--- | :--- |
| [`newminhh/newminhh`](https://github.com/newminhh/newminhh) | `/` | Umbrella orchestration (`Makefile`, `bin/newminhh`), VM tooling (`vm/`), verification & benchmarks (`tests/`) |
| [`newminhh/common`](https://github.com/newminhh/common) | `src/common/` | Shared C/assembly ABI contract (`newminhh_cpu_t`, struct layouts, signature descriptors, integration hooks, logging) |
| [`newminhh/compat`](https://github.com/newminhh/compat) | `src/compat/` | `libnewminhh_compat.so`: bidirectional cdecl<->x32 assembly bridges, W^X trampoline pools, syscall translation, struct repacking, `dlopen`/`dlsym`, and libc/libm/pthread wrappers |
| [`newminhh/dbt`](https://github.com/newminhh/dbt) | `src/dbt/` | `libnewminhh_dbt.so` & `newminhh-run`: in-process Capstone x86-to-x86-64 JIT translator, ELF32 loader, 64K indirect-branch cache, edge chaining, and `SIGSEGV` NX-guard callbacks |
| [`newminhh/patcher`](https://github.com/newminhh/patcher) | `src/patcher/` | `newminhh-patch` & `re_patcher`: containerized (`re-env:latest`) multi-tool static analyzer (`elftools`, `capstone`, `angr`, `r2`, `ghidra`), 4-byte-stride Long Mode rewriter, x32 GAS trampoline builder, and hybrid DBT fallback |
| [`newminhh/tests`](https://github.com/newminhh/tests) | `tests/` | Parts 1–5 verification corpus (`C01`–`C11`, `S01`–`S03`, `N01`–`N09`), regression suites, and `/proc/<pid>/smaps` + timing benchmark harness |
| [`newminhh/vm_test_scripts`](https://github.com/newminhh/vm_test_scripts) | `vm/` | Debian `x32` `libvirt-qemu` provisioning, execution, console, and `x32`-only verification scripts |
| [`newminhh/docs`](https://github.com/newminhh/docs) | `docs/` | Comprehensive overview, deep architecture reference, and VM/testing/benchmarking documentation |
| [`newminhh/agent-notice`](https://github.com/newminhh/agent-notice) | *(archived)* | Archived `PROJECT.md` and `.agents/` planning, review, and Victory Audit artifacts |

---

## Quick Start

> [!IMPORTANT]
> **Kernel Requirements Notice (Mainline Linux `x32` ABI Removal in 2026):**
> Mainline Linux moved in 2026 to deprecate and remove `CONFIG_X86_X32_ABI` ([Phoronix: *Linux x32 ABI in 2026*](https://www.phoronix.com/news/Linux-x32-ABI-2026), [LWN](https://lwn.net/Articles/1074897/)). To run `newminhh` natively or inside a guest VM, the target kernel **must**:
> 1. Be compiled with **`CONFIG_X86_X32_ABI=y`** (or `CONFIG_X86_X32=y`) — e.g., Linux `3.4`–`7.2`, pre-removal Debian `7.3` `amd64` kernels, an LTS kernel (`6.1` / `6.6` / `6.12` / `6.18`) built with `CONFIG_X86_X32_ABI=y`, or a custom kernel with `x32` removal reverted.
> 2. Be booted with **`syscall.x32=y`** on the kernel command line (plus **`ia32_emulation=0`** for pure `x32`-only isolation).
> *(Note: When using the `vm/` KVM guest workflow, only the guest kernel inside `newminhh-x32` requires `CONFIG_X86_X32_ABI=y` + `syscall.x32=y`; the `x86_64` KVM host kernel does not need `x32` enabled.)*

### 1. Provision & Verify the Debian x32 VM (x86_64 Host)

```bash
bash vm/vm-provision.sh   # rootless Debian sid x32 VM via Docker mmdebstrap + libvirt
./bin/newminhh vm up      # boot VM & wait for SSH readiness
./bin/newminhh vm verify  # confirm uname -m=x86_64, ia32_emulation=0, 0 :i386 packages
```

### 2. Build & Install

```bash
./bin/newminhh build --install
# Equivalent Make commands:
#   make build
#   make install
```

This cross-compiles the i386 corpus (`tests/corpus`), syncs sources to `newminhh-x32`, compiles `libnewminhh_compat.so`, `libnewminhh_dbt.so`, `newminhh-run`, and x32 baselines inside the VM, and installs them into `/usr/local/lib/x86_64-linux-gnux32` and `/usr/local/bin`.

### 3. Run or Patch i386 Binaries

```bash
# Execute an unpatched i386 executable via in-process DBT:
./bin/newminhh run tests/corpus/build/i386/cli_libc_pie

# Invoke an exported symbol from an unpatched i386 .so:
./bin/newminhh run --so tests/corpus/build/i386/libplugin_stripped.so plugin_compute 7 5

# Statically patch an i386 binary into a native x32 EM_X86_64 ELF32 (via Docker re-env:latest):
./bin/newminhh patch tests/corpus/build/i386/cli_libc_pie -o /tmp/cli_libc_pie.x32
```

### 4. Test & Benchmark

```bash
./bin/newminhh test all                  # clean build, CLI checks, Parts 1-4, & Part 5 benchmarks
./bin/newminhh test part3                # static/hybrid patcher verification
./bin/newminhh bench --daemons 4 --samples 5   # /proc/<pid>/smaps sharing & timing comparison
```

---

## Repository Layout

```text
.
├── Makefile                # Host/guest-aware build, VM sync, test & benchmark orchestration
├── bin/newminhh            # Unified CLI (build, patch, run, test, bench, vm)
├── docs/                   # Documentation (https://github.com/newminhh/docs)
├── src/
│   ├── common/             # Shared ABI headers (https://github.com/newminhh/common)
│   ├── compat/             # Compatibility runtime library (https://github.com/newminhh/compat)
│   ├── dbt/                # In-process DBT engine & loader (https://github.com/newminhh/dbt)
│   └── patcher/            # Static/hybrid ELF patcher (https://github.com/newminhh/patcher)
├── vm/                     # Rootless Debian x32 libvirt-qemu VM scripts & domain template
└── tests/
    ├── corpus/             # 13 CLI + 3 .so + 9 negative (N01-N09) + benchmark fixtures (Part 1)
    ├── part2/              # libnewminhh_compat.so C + ASM ABI tests
    ├── part3/              # Static/hybrid patcher & fallback tests
    ├── part4/              # Runtime DBT & multi-threaded stress tests
    └── part5/              # Reproducibility, CLI & /proc/<pid>/smaps benchmark runner
```

---

## Further Reading

- [`docs/README.md`](https://github.com/newminhh/docs/blob/main/README.md) — Overview, installation, and CLI reference
- [`docs/ARCHITECTURE.md`](https://github.com/newminhh/docs/blob/main/ARCHITECTURE.md) — ABI tables, register usage, memory layout, trampolines, syscalls, struct repacking, JIT emitter, and static ELF rewriting
- [`docs/TESTING_AND_VM.md`](https://github.com/newminhh/docs/blob/main/TESTING_AND_VM.md) — VM provisioning scripts and Parts 1–5 verification & `/proc/<pid>/smaps` benchmarking suites
