# Usage in C

There are two completely different uses of the keyword `static` in C.

The first, and simplest, is to define `static` member variables inside
functions which makes the function non-reentrant. The variable defined as
`static` is allocated space at build time and persists between function calls.
The variable is allocated space in the data / BSS segment of the program and
persists throughout the life of the program.

The second use, quite different from the first, is when `static` is used on
variables or functions in file scope. Here it makes sense to make the
assumption, which the kernel enforces, that a translation unit includes a `.c`
source file and the headers which are included via the `#include` preprocessor
directives. When `static` appears on a function or variable definition in file
scope, it is not visible to the linker and does not get exported beyond that
translation unit (i.e., that file). It provides a private namespace within that
translation unit without any risk of name collisions with identically-named
symbols in other translation units. One consequence of this is that `static`
variables in file scope are allocated space within the data / BSS segment and
persist throughout the life of the program. Hence, `static` variables in file
and function scope both exist in the same segment, albeit for different
reasons.

One final note on the use of `extern` which is related. An `extern` declaration
in one translation unit states that a symbol exists that will be found by the
linker in a different translation unit. This carries the notion that wherever
that symbol is actually defined must necessarily be defined without the
`static` keyword, or the linker would not be able to find it, causing a linker
error.

# Usage with inline functions

An additional use case for `static` is when defining `inline` functions. Inline
functions need to have their entire definition in header files so every
translation unit that uses that can inline the body of the function at the call
site. Consider the case:

```text
  header.h includes a definition of `inline void(foo)`
  file_a.c includes header.h and gets a definition of `foo`
  file_b.c includes header.h and gets a definition of `foo`
```

So both object files `.o` export the function `void foo` which the linker sees
as multiple definitions and errors out. To prevent this from happening,
`inline` functions need to be defined as `static inline` functions to prevent
multiple-definition errors at link time.
