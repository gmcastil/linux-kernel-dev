# Experiment 01: No Floating Point in the Kernel

This is the first exercise that's a real out-of-tree kernel module rather than
a standalone userspace program — built against your `linux-v6.18` clone's
headers, the way a driver would be. That's why it lives in `experiments/`
rather than `exercises/` (see the layout note in CLAUDE.md). Part A only needs
a successful *build*, not a booted VM — `make M=... modules` produces a `.ko`
without ever loading it. Only the optional last step needs `insmod`.

## Background

The kernel doesn't let core code touch the FPU/SSE/AVX registers casually, for
two compounding reasons:

1. **Whose register state is it anyway?** The kernel doesn't save/restore
   FP/SIMD register state on every entry into the kernel (every syscall, every
   interrupt) — that state is large (the FXSAVE/XSAVE area, bigger still with
   AVX-512) and saving it unconditionally on every kernel entry "just in case"
   would be pure overhead for the overwhelming majority of entries that never
   touch it. FP/SIMD state is only saved/restored around context switches
   between *user* tasks. If kernel code used the FPU mid-syscall without
   explicitly accounting for this, it would clobber whatever floating-point
   computation belonged to the user process that happened to be interrupted or
   that made the syscall — corrupting completely unrelated userspace state.
2. **The compiler enforces it, not just convention.** Core kernel code is
   built with flags that forbid the compiler from emitting hardware FP
   instructions at all. This isn't a lint warning you can shrug off — using a
   `float`/`double` in kernel code will fail to compile or fail to link
   (the kernel doesn't provide the softfloat helper routines from `libgcc`
   that ordinary userspace code silently links against).

For the rare legitimate cases — RAID6 XOR acceleration, AVX-accelerated
crypto, KVM emulating a guest's FPU — x86 has a narrow, explicit escape hatch:
`kernel_fpu_begin()`/`kernel_fpu_end()`. These save the interrupted context's
FPU state, let you safely use the hardware, then restore it. It's a contained,
audited mechanism, not something used casually.

## The task

### Part A — watch the build refuse it

1. Set up a standard out-of-tree module skeleton (`obj-m` Kbuild Makefile,
   built via `make -C <path-to-linux-v6.18> M=$(pwd) modules`). If you haven't
   done this pattern before in this repo, `Documentation/kbuild/modules.rst`
   in your `linux-v6.18` clone has the exact recipe.
2. Write a trivial module whose `init` function declares a `float` or
   `double`, does some arithmetic with it (e.g. averaging a couple of ints),
   and tries to print the result. Note `printk` has no `%f` — you'll need to
   convert to an integer or fixed-point representation just to print it,
   which is itself a small taste of "no FP" reality reaching even into
   diagnostics.
3. Run the build and read the actual error closely — note exactly what it's
   complaining about (a compile error vs. a link error tells you something
   different about where the restriction is enforced).
4. Run `make V=1 -C ../linux-v6.18 M=$(pwd) yourmodule.o` (adjust the object
   name) to see the literal compiler command line Kbuild used to (try to)
   build that file. Find the actual flag responsible for forbidding hardware
   FP — something in the spirit of `-mno-sse`/`-msoft-float`/
   `-mgeneral-regs-only`, exact spelling depends on architecture and kernel
   version. This turns "the kernel disallows FP" from something you take on
   faith into a specific flag you can point at.

### Part B — do it the sanctioned way

5. Wrap the same arithmetic in `kernel_fpu_begin()`/`kernel_fpu_end()` (cscope
   these in `linux-v6.18` — declared in `arch/x86/include/asm/fpu/api.h`) and
   rebuild. Confirm it now compiles and links cleanly.
6. **Optional**, only if your VM's `insmod`/`rmmod`/`dmesg` workflow is
   already solid: load the module, check `dmesg` for your printed result,
   unload it.

## What to notice

- The Part A failure is a hard build error, not a style nit — that's a strong
  signal of how seriously this constraint is taken.
- `kernel_fpu_begin()`/`kernel_fpu_end()` existing at all tells you the
  constraint isn't "the hardware can't do this," it's "you must explicitly
  declare you're borrowing this state and give it back."

## Kernel connection

cscope for callers of `kernel_fpu_begin()` in `linux-v6.18` to see it used for
real: RAID6 XOR routines under `lib/raid6/`, AVX-accelerated paths under
`arch/x86/crypto/`, and KVM's guest FPU handling.

## Building

```bash
make -C ../linux-v6.18 M=$(pwd) modules
```