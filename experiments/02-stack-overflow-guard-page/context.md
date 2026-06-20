# Experiment 02: The Small, Fixed-Size Kernel Stack

This one deliberately oopses/panics your kernel inside the QEMU VM. That's
the point, and it's completely safe — it's exactly the disposable environment
the VM exists for. Just be ready to restart the VM afterward. This needs your
`insmod`/boot workflow actually working, unlike experiment 01's Part A, since
overflowing a stack is a runtime event, not something a build step can show
you.

## Background

Each kernel thread gets a small, fixed-size stack — `THREAD_SIZE`, commonly
16KB on 64-bit x86 today (it was 8KB on 32-bit x86 in the book's era) — versus
a userspace thread's stack, which is typically megabytes and can often grow
on demand. It's fixed and small on purpose:

- The kernel may have thousands of threads/tasks alive at once, each needing
  a kernel stack that is real, pinned memory (historically not swappable) —
  over-provisioning at that scale is wasteful.
- Making the budget small and fixed is itself a forcing function: it makes
  the cost of careless stack usage (deep/unbounded recursion, large on-stack
  buffers) show up immediately during development, instead of becoming a
  someday-it-blows-up-in-the-field bug.

The modern-era detail worth knowing: overflowing a kernel stack used to be a
*quiet* form of corruption — silently overwriting whatever lived in the next
page of the kernel's address space, usually some unrelated, innocent data
structure. `CONFIG_VMAP_STACK` (default on x86_64, merged ~4.9 — well after
this book's 2.6.34 baseline) maps each kernel stack in the vmalloc area with
an unmapped guard page immediately adjacent. An overflow now faults
immediately into that guard page instead of corrupting a neighbor. It's the
same fail-fast instinct as putting a sentinel value past the end of a
hardware FIFO and asserting on it in simulation, rather than letting an
overrun silently scribble into the next register.

## The task

1. Write a small out-of-tree module whose `init` function calls a
   deliberately deep recursive function — each frame holding a sizeable local
   array (a couple hundred bytes) to burn through stack quickly. A few
   hundred levels of recursion at ~200 bytes/frame should clear 16KB easily.
   Do something with the local array *after* the recursive call (sum it,
   touch a byte) so GCC can't tail-call-optimize the frame away.
2. Check whether your `linux-v6.18` build has the guard-page mechanism
   enabled: `grep VMAP_STACK` your kernel `.config`.
3. Before triggering the overflow, confirm the actual numeric size you're
   working against rather than trusting "16KB" as a quoted fact: add a
   `printk("THREAD_SIZE = %lu\n", THREAD_SIZE);` to your module's `init` —
   or, since `THREAD_SIZE` is resolved via macro arithmetic rather than a
   literal, run `make -C ../linux-v6.18 M=$(pwd) yourmodule.i` and grep the
   preprocessed output for how it actually expands on your build.
4. Build the module, boot the VM, `insmod` it.
5. Read whatever comes out on the console/`dmesg`. With `CONFIG_VMAP_STACK`
   on, expect a stack-overflow oops/panic pointing at a guard-page fault,
   rather than a hang or silent corruption.

**Optional, conceptual only — don't actually do this broadly:** if you ever
rebuilt a kernel with `CONFIG_VMAP_STACK` off, the same overflow would become
a much uglier failure to diagnose — silent corruption of whatever's adjacent,
not an immediate labeled fault. Worth knowing the contrast exists; not worth
a real rebuild just to see it.

## What to notice

- Look at exactly how the panic/oops identifies the fault — does it call out
  a stack overflow specifically, or just report a page fault at a
  suspicious-looking address that you have to interpret yourself?
- This is the same "fail loudly at a guarded boundary" idea you'd reach for
  in RTL with a sentinel/assertion at a buffer boundary — same motivation,
  different layer.

## Kernel connection

- `THREAD_SIZE`/`THREAD_SIZE_ORDER` — `arch/x86/include/asm/page_64_types.h`
  in `linux-v6.18`.
- The guard-page mechanism itself — cscope `vmap_stack` in `linux-v6.18`,
  especially under `arch/x86/kernel/` and `kernel/fork.c`'s thread-stack
  allocation path.
- Real driver relevance: this is exactly why drivers avoid large on-stack
  buffers and recursion as a matter of course — an ISR or a deeply nested
  call chain blowing the stack is a classic, hard-to-diagnose driver bug
  (worth keeping in mind once you're writing the UART driver).

## Building

```bash
make -C ../linux-v6.18 M=$(pwd) modules
# boot the VM, then:
insmod stack_overflow.ko   # or whatever you name the module
dmesg | tail -n 60
```