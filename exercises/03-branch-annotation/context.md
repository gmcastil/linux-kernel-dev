# Exercise 03: Branch Annotation, and Reading Preprocessed Output

## Background

`likely(x)`/`unlikely(x)` wrap a GCC builtin:

```c
#define likely(x)   __builtin_expect(!!(x), 1)
#define unlikely(x) __builtin_expect(!!(x), 0)
```

They tell the compiler which way a branch is expected to go almost all the
time. The main effect today is code *layout*: the likely path stays as the
fall-through, the unlikely path gets pushed out of line, away from the hot
instruction-cache footprint. (Modern CPUs' own dynamic branch predictors learn
real behavior quickly regardless of the hint — see the discussion in this
chapter's notes for why the layout effect, not prediction, is the part that
still matters.)

This exercise has a second, more general goal: learning to look at
**preprocessed output** (`gcc -E`) and **generated assembly** (`gcc -S` /
`objdump -d`) directly, instead of trusting a macro definition from memory.
This is a skill you'll want repeatedly for the rest of the book — any time a
macro-heavy kernel header is doing something unclear, dropping to the
preprocessor's actual output settles it. We're attaching it to this exercise
because `likely`/`unlikely` gives a clean, small case to practice on, but the
technique generalizes to anything.

## The task

### Part A — annotate a real skew

1. Write a function that processes a large array (a few million ints) and
   checks each element against a condition that's true for the overwhelming
   majority and false for a rare few — e.g., "is this value within a normal
   range" vs. a handful of injected sentinel/error values. Use `unlikely()`
   around the rare-error branch.
2. Define your own `likely`/`unlikely` macros locally (same definition as
   above) rather than pulling in a kernel header — keep this self-contained.

### Part B — look at the preprocessed source

3. Run `gcc -E main.c -o main.i` and open `main.i`. Find the line where you
   wrote `unlikely(some_condition)` in your source, and find what it became
   after preprocessing.
4. Notice that it expanded to `__builtin_expect(!!(some_condition), 0)` and
   **stopped there** — `__builtin_expect` itself is not a macro, so the
   preprocessor (`cpp`, which is all `-E` runs) leaves it completely alone.
   It's the compiler proper (`cc1`) that understands and consumes
   `__builtin_expect` later, during actual code generation. This is the
   preprocessor/compiler boundary: `-E` only unwinds textual macro
   substitution, nothing more.

### Part C — confirm the codegen effect

5. Compile to assembly twice at `-O2`: once with your `unlikely()` annotation
   in place, once with it stripped out (condition used bare). `gcc -O2 -S
   main.c -o with_hint.s` and `-o without_hint.s`.
6. Diff the two `.s` files (or just read both around the branch in question).
   Look for: which branch is the fall-through vs. a taken jump, and whether
   the rare-path code block has moved away from the main flow of the function
   (possibly to a separate location entirely, depending on GCC version and
   how aggressively it's hoisting cold code).

## What to notice

- The preprocessor and the compiler proper are separate programs (literally —
  `cpp` then `cc1` then `as`, chained together by the `gcc` driver). `-E`
  stops after the first stage and shows you exactly what the second stage
  receives. This is the general technique for "what does this macro actually
  expand to" for *any* macro, not just this one — including the ones from
  exercise 01/02 you defined yourself.
- `__builtin_expect` surviving preprocessing untouched, then disappearing by
  the time you get to assembly, shows you concretely where a GCC builtin
  differs from a macro: a macro is gone after `-E`, a builtin is gone only
  after `-S`/full compilation.
- Whether the assembly actually changed shape between Part C's two versions
  is itself useful data — at high optimization levels GCC may already reorder
  things the same way without your hint if the skew is obvious from context
  (e.g., a condition right after a `malloc`/`NULL` check). The hint matters
  most when the compiler has no other information to go on.

## Kernel connection

`likely`/`unlikely` are defined in `include/linux/compiler.h` in your
`linux-v6.18` clone — worth a quick look to confirm the real macro matches
what you wrote here, and to see what else lives nearby (`compiletime_assert`,
the various `__must_check`/`__pure` attribute wrappers — all in the same
"compiler-hint" neighborhood). For real usage in context, pick something with
an obvious, extreme skew — `kmalloc`'s callers checking for a `NULL` return,
or `WARN_ON`/`BUG_ON` conditions — and cscope to a few call sites.

## Building

```bash
gcc -Wall -Wextra -O2 -E main.c -o main.i      # preprocessed source
gcc -Wall -Wextra -O2 -S main.c -o with_hint.s # assembly, hint in place
# (edit/comment out the unlikely() call, or use a second source file)
gcc -Wall -Wextra -O2 -S main_nohint.c -o without_hint.s
diff with_hint.s without_hint.s
```