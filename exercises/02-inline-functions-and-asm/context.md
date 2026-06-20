# Exercise 02: Inline Functions and Inline Assembly

## Background

`inline` asks the compiler to paste a function's body directly at the call site
instead of emitting a real call — no push-args/jump/return, just the code, right
there. The kernel prefers `static inline` functions over macros for this in
headers: you get real type checking and scoping, but still get inlined at `-O2`
like a macro would. `static` matters too — it gives the function internal linkage
per translation unit, so including the header from multiple `.c` files doesn't
cause a multiple-definition error at link time.

Inline assembly (`asm`/`__asm__`) lets C code emit a literal target-architecture
instruction the compiler wouldn't generate on its own — atomics, control
registers, port/MMIO instructions, memory barriers, `rdtsc`. You hand the
compiler a constraint string (`"=r"` for an output register, `"r"` for an input
register, etc.) telling it which registers/memory your instruction touches and
what's safe to leave alone.

These two ideas combine constantly in kernel headers: a `static inline` function
whose entire body is one inline-asm instruction. That gets you a type-checked,
normally-named "intrinsic" — call it like a function, get exactly the instruction
you asked for, and (once inlined) no call overhead. `readl`/`writel` — the
memory-mapped register accessors you'll use once your UART RTL exists — are
exactly this pattern, which is why this exercise merges the two topics instead
of treating them separately.

This is a userspace demo — no real hardware or kernel privilege involved. The
"register" is a plain process-memory stand-in for what would, on real hardware,
be a pointer returned by `ioremap`/`of_iomap`.

## The task

### Part A — fake MMIO accessors

1. Declare `static volatile uint32_t fake_reg;` as a stand-in for a hardware
   register.
2. Write `static inline uint32_t fake_readl(const volatile uint32_t *addr)` and
   `static inline void fake_writel(volatile uint32_t *addr, uint32_t val)`.
   Implement each body with inline assembly doing a single `mov` between the
   given address and a register. (Look up GCC's inline-asm operand-constraint
   syntax for this — that's the main new mechanic here.)
3. Write a `main()` that writes a few values to `fake_reg` via `fake_writel`
   and reads them back via `fake_readl`, printing each.

### Part B — a function whose whole point is being inlined

4. Write `static inline uint64_t rdtsc(void)` wrapping the x86 `rdtsc`
   instruction (output-only constraints — a useful contrast to Part A's
   read/write). Use it to time something repetitive, e.g. a million
   `fake_writel`/`fake_readl` round trips, and print the elapsed cycle count.
5. Remove `volatile` from `fake_reg` (or the pointer parameters) and rebuild
   at `-O2`. See what happens to your read/write loop.

### Part C — proving inlining actually happened

6. Build the same source three ways: `-O0`, `-O2`, and `-O2` with
   `__attribute__((noinline))` added to `fake_readl`. After each build, run
   `objdump -d <binary>` (or `nm <binary>`) and check whether `fake_readl`
   appears as its own labeled symbol, or whether its instructions are folded
   directly into `main`'s disassembly with no `call`/`ret` around them.
7. Add `__attribute__((always_inline))` to `rdtsc` and confirm via `objdump`
   that it gets inlined even compiling the whole file at `-O0`, where GCC's
   default heuristics normally inline almost nothing.

## What to notice

- `volatile` is what separates "the compiler may elide reads/writes it thinks
  are redundant" from "touch memory every single time, in order." A real
  hardware register cares about every access; an ordinary variable doesn't.
  Step 5 should visibly change (or break) your loop at `-O2` — that's the
  entire reason MMIO accessors and pointers are always `volatile` in the kernel.
- The constraint string is a real contract with the compiler about what your
  asm block reads/writes. Get it wrong and the compiler can silently put other
  live data in a register your instruction is secretly clobbering.
- `inline` the keyword is a request, not a guarantee — what `objdump` shows you
  in Part C is the ground truth for whether a specific binary actually inlined
  a specific call. `__always_inline`/`noinline` are how you override the
  compiler's heuristic in either direction.

## Kernel connection

Architecture MMIO headers (`arch/x86/include/asm/io.h`, `arch/arm/include/asm/io.h`)
define `readb/readw/readl/writeb/writew/writel` as exactly this pattern: a
`static inline` function, a `volatile` pointer, one load or store (sometimes plus
a barrier), sometimes via inline asm and sometimes via a plain volatile
dereference depending on architecture. Once your UART exists, every register
touch — control register, FIFO status, baud divisor — goes through one of these,
never a raw pointer dereference. `drivers/tty/serial/xilinx_uartps.c` and
`uartlite.c` use `readl`/`writel` exclusively, for this exact reason.

`rdtsc` itself shows up in the kernel too, as a backend for `get_cycles()`/the
TSC clocksource on x86 — used wherever the kernel wants a cheap, high-resolution
timestamp without a syscall.

## Building

Unlike exercise 01's single build, Part C wants the same source built three
different ways. A small Makefile with a few targets (or just repeated manual
`gcc` invocations) both work fine — your call. Roughly:

```bash
gcc -Wall -Wextra -O0 -g -o inline_demo_O0 main.c
gcc -Wall -Wextra -O2 -g -o inline_demo_O2 main.c
objdump -d inline_demo_O0 | less
objdump -d inline_demo_O2 | less
```