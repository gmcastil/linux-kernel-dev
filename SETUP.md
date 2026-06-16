# Setting Up a Development Environment

## Obtaining a Compatible Toolchain

Obtain one of the toolchains used by the kbuild test robot which tests every
patch submitted to the LKML across many target architectures and many GCC
versions. The 2.6.34 version was built against GCC 4.4, which is older than
what the automated system uses. We're going to grab it and see if it actually
builds an older version of the kernel.

```bash
wget https://www.kernel.org/pub/tools/crosstool/files/bin/x86_64/4.9.4/x86_64-gcc-4.9.4-nolibc-x86_64-linux.tar.gz
```
