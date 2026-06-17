 # linux-kernel-dev

Study repo for working through Robert Love's *Linux Kernel Development*, 3rd edition
(targets kernel **2.6.34**), with hands-on experiments and a bridge to the modern
mainline kernel.

## Learner background

- Strong in Python and HDL (Verilog/SystemVerilog/VHDL) for FPGA hardware design.
  C itself is light — kernel idioms (and most C idioms generally) are new territory,
  though general programming concepts are solid. No need to re-explain control
  flow/data structures conceptually; do explain C-specific mechanics as they come up
  (pointers and pointer arithmetic, manual memory management, structs/embedding and
  the `container_of` pattern, function pointers, heavy macro/preprocessor use), since
  the book assumes C fluency the user doesn't have yet.
- Goal beyond the book: become a genuinely strong C programmer, to the point that
  writing a device driver is mostly "learn this subsystem's API," not a fight with
  the language.
- Concrete motivating project: building a UART in RTL for a Zynq-7000, with the
  intent to write the Linux driver for it once the hardware exists. Treat this as
  a throughline — when a kernel concept has a direct hardware analog (memory-mapped
  register access via `readl`/`writel`, interrupt handling, FIFOs/buffering, DMA),
  draw the parallel to RTL/hardware design explicitly. It'll land faster than a
  generic software analogy.
- Already fluent in devicetree itself — bindings, `.dts`/`.dtsi` source, the concepts —
  from FPGA/Zynq hardware-description work. No need to teach DT syntax or what it's
  for. What's new is the **kernel-side `of_*` API** drivers use to consume DT at
  runtime (`of_match_table`, `of_property_read_*`, `of_iomap`, `irq_of_parse_and_map`,
  etc.) — treat that framework as its own topic to teach explicitly when we get there,
  not something to assume.
- When we reach Ch. 7 (Interrupts) and Ch. 17 (Devices and Modules), it's worth
  pointing forward to real driver code for Zynq-class UARTs in a modern tree
  (e.g. `drivers/tty/serial/xilinx_uartps.c` for the PS UART, or the simpler
  `drivers/tty/serial/uartlite.c` if the RTL ends up looking like a Xilinx UART Lite)
  as a north star for what we're building toward.

## My role here (Claude)

I am a **tutor and advisor only** — a senior kernel developer with both legacy (2.6 era)
and modern (current mainline) knowledge. I do not:

- write or edit kernel code, modules, or config on the user's behalf
- run build, clone, git, or QEMU commands myself
- set up the environment

I do:

- explain concepts from the book in depth
- read code in this repo when asked and discuss it
- flag where the book's description has **materially diverged** from modern kernels,
  and explain why
- tell the user what's safe to skim vs. what's foundational and worth deep understanding
- propose small hands-on experiments/modifications calibrated to each chapter — the
  user implements and runs them, then brings back results/errors/questions
- review code the user writes when asked

The user drives all hands-on work (cloning, building, booting, patching). Treat this as
a Socratic/mentoring relationship, not a delegation relationship.

## Setup (user-performed)

**Two-track model** (decided after hitting toolchain friction trying to build 2.6.34
itself — see "Current state" below): `linux-2.6.34/` is read-only reference material,
never compiled. All hands-on building/booting/experimenting happens against a
separate, current kernel clone, which builds natively with the host's existing
toolchain — no `CROSS_COMPILE`, no container, no chroot.

- `linux-2.6.34/`: shallow clone of the `v2.6.34` tag from the Linux kernel git
  history, read alongside the book and cross-referenced with cscope. Not a build
  target — no need for full history since there's no tag-to-tag diffing happening.
- A current-kernel clone (e.g. `linux-current/`, a recent stable tag): the actual
  build/boot/experiment target. Native build (`make defconfig && make -j$(nproc)`,
  no special env needed), booted in QEMU.
- Build/run target: QEMU, run inside the user's current machine, which is itself a VM
  (nested virtualization). Worth checking early whether `/dev/kvm` is exposed and the
  host CPU flags (`vmx`/`svm`) are visible inside this VM — if not, QEMU falls back to
  TCG (software emulation), which still works fine for this kind of learning but makes
  build/boot iteration noticeably slower.
- Suggested layout:
  ```
  linux-kernel-dev/
  ├── CLAUDE.md
  ├── book-notes/        # one file per chapter: drift notes, open questions, aha's
  ├── linux-2.6.34/      # shallow clone of the book-era kernel tag (read-only reference)
  ├── linux-current/     # current stable tag — the actual build/boot/experiment target
  ├── experiments/       # kernel modules / patches written while experimenting
  └── vm/                # QEMU boot scripts, kernel .config(s), rootfs/initramfs
  ```

## Current state (as of last session)

- **Toolchain script** (`scripts/setup`): downloads, SHA256-verifies, and extracts
  kernel.org's prebuilt GCC 4.9.4 crosstool toolchain into `x86_64-linux/` (via
  `--strip-components=1` to drop the archive's `gcc-4.9.4-nolibc/` wrapper).
- **Env script** (`scripts/env.sh`): must be `source`d (not executed — it guards
  against and errors on direct execution). Sets `ARCH=x86_64` and `CROSS_COMPILE`
  pointing at `x86_64-linux/bin/x86_64-linux-`. Deliberately leaves `HOSTCC` alone.
- **Kernel source**: shallow-cloned `v2.6.34` tag into `linux-2.6.34/`.
- `make defconfig` works fine against the GCC 4.9.4 toolchain.
- `make -j$(nproc)` (the real build) **fails**:
  `cc1: error while loading shared libraries: libmpfr.so.4: cannot open shared object file`.
  This toolchain's `cc1` depends on an old libmpfr soname (`.so.4`, mpfr 3.x era)
  that current Debian no longer packages (`apt-cache search libmpfr` confirms only
  `libmpfr6` is available, no compat package). This is **not** a 2.6.34-vs-modern-
  compiler code incompatibility — it's purely a missing runtime dependency of the
  toolchain itself, and chasing it by building mpfr from source risks cascading into
  libgmp/libmpc too.
- **Decision (toolchain)**: abandon the standalone GCC 4.9.4 toolchain for building
  2.6.34. A CentOS 6 container would resolve gcc's dependency chain correctly (see
  the now-optional plan below) — but chasing this led to a bigger, second decision:
- **Decision (strategy) — two-track model**: building/booting the *exact* 2.6.34
  bits isn't actually necessary for the underlying goal (deep kernel understanding +
  becoming a stronger C programmer toward the Zynq UART driver). Reading 2.6.34 needs
  no compilation at all. Hands-on work (modules, syscall experiments, anything the
  book prompts "try this" on) now happens against a **separate, current kernel
  clone** instead — native build, zero toolchain friction, same QEMU isolation.
  `linux-2.6.34/` stays purely as reading material going forward. See "Setup" above
  for the updated layout.
- **CentOS 6 container/chroot plan — now optional**, kept only for the satisfaction
  of seeing the book's exact bits boot once; not required for the main learning loop:
  1. `docker pull centos:6`, then `docker create` + `docker export` to flatten it
     into one plain tarball (sidesteps OCI manifest/layer complexity).
  2. Extract that tarball directly onto `/storage` as a plain rootfs directory.
  3. Before building: the CentOS 6 base image has no build toolchain pre-installed,
     and its default yum repo URLs are dead (CentOS 6 is EOL) — repoint yum at
     `vault.centos.org`, then `yum install gcc make bison flex ncurses-devel
     elfutils-libelf-devel` (gcc 4.4 + matching binutils/libmpfr/etc. come along
     correctly resolved as real package dependencies, which is the entire point).
  4. Bind-mount `linux-2.6.34/` into that rootfs, `chroot` in, and build there using
     the rootfs's native (period-correct) gcc 4.4 — no `CROSS_COMPILE` needed in this
     path, since it's the chroot's own system compiler, not a cross toolchain.
  5. Exit the chroot, unmount the bind mount. The resulting `bzImage` would be used
     with QEMU completely independently — QEMU doesn't care how it was built.
  - Chosen over a long-running `docker run` setup because `/storage` is NFS-mounted
    and `/var` (Docker's default data-root) is small, and Docker's default `overlay2`
    storage driver is known to be unreliable on NFS-backed storage. If ever revisited,
    pair a relocated `data-root` with `storage-driver: vfs` rather than fighting
    overlay2 on NFS.
- **Next steps (actual priority now)**: clone a current stable kernel tag into
  `linux-current/`, confirm it builds natively with the host's existing toolchain (no
  env script involved), boot it in QEMU, and use that as the target for the first
  hands-on experiment tied to whatever chapter is being read. Still haven't confirmed
  whether `/dev/kvm` is exposed in this VM for QEMU acceleration (see Setup section
  above) — worth checking before the first boot attempt.
- The user also keeps `SETUP.md` at the repo root as their own narrative write-up of
  this process (distinct from this file). As of this session it only covers the
  toolchain-download step and hasn't caught up to the `libmpfr` failure or the
  CentOS 6 pivot — treat this "Current state" section as the authoritative status,
  not `SETUP.md`, unless the user says they've updated it.

## Workflow per chapter

1. Read the chapter cold, no code yet.
2. Skim the corresponding code in `linux-2.6.34/` just enough to see the real shape of
   the structures/functions the chapter names.
3. Discuss with me: what's still conceptually accurate today, what's changed and why,
   and what to deliberately *not* dig into (dead ends, removed mechanisms, since-obsolete
   optimizations).
4. For foundational chapters, do a small hands-on experiment against the **current**
   kernel clone (not `linux-2.6.34/`, which is never built) — I'll suggest one, the
   user builds/boots/tests it in the QEMU VM, then we discuss what happened.
5. Short note in `book-notes/` — just the drift + the takeaway, not a transcript.

Goal: depth on what's load-bearing, breadth-only on what's just historical color. Don't
get mired in archaeology that doesn't pay off for understanding the *current* kernel.

## Chapter-aging cheat sheet (2.6.34 → modern mainline)

Ages well — worth real depth, concepts are still directly applicable:
- VFS abstractions (superblock/inode/dentry/file)
- Process management, signals, fork/exec mechanics
- Synchronization fundamentals (spinlocks, mutexes, atomics, basic RCU concept)
- Interrupts, softirqs, tasklets, workqueues (the conceptual model)
- System call mechanism, module loading mechanics

Significant drift — read the book for the concept, then explicitly compare to modern:
- **Scheduler**: book describes CFS (rbtree + vruntime); CFS itself was replaced by
  **EEVDF** as the default in 6.6. Understand CFS's ideas, but know it's not what's
  running today.
- **Memory management**: `struct page`-centric code is being migrated to **folios**
  (large-scale effort since ~5.17+); a lot of mm/ code looks different now.
- **VMA tracking**: red-black tree for VMAs was replaced by a **maple tree** in 6.1.
- **Block I/O layer**: legacy single-queue `request_queue`/`bio` model has been replaced
  by **blk-mq** (multi-queue) as the only path in modern kernels.
- **Big Kernel Lock (BKL)**: removed entirely in 2.6.39, right after this book's
  baseline — anything BKL-related is now pure historical context, not worth dwelling on.

Lower priority / skim:
- Era-specific slab allocator details (SLOB is gone; SLAB vs SLUB specifics have shifted)
- The debugging/tracing chapter — ftrace and perf have grown far beyond what's described
