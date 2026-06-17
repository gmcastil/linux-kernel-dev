# Exercise 01: Function Pointers and Vtables in C

## Background

The Linux kernel fakes OOP polymorphism using structs of function pointers acting
as vtables. The canonical example is `struct file_operations` — a table of pointers
to functions (`read`, `write`, `open`, `ioctl`, etc.) that a driver fills in. The
VFS calls through that table without knowing what's underneath. Same call site,
different behavior depending on which table is pointed to.

This exercise builds that mechanic from scratch in plain C, no kernel involvement.

## The task

Model a simple "device" abstraction with two concrete implementations: a "serial"
device and a "null" device.

1. Define an operations struct (`struct device_ops`) with two function pointers:
   - `read`: takes a buffer pointer and a size, returns number of bytes read
   - `write`: takes a buffer pointer and a size, returns number of bytes written

2. Define a device struct (`struct device`) that holds:
   - A pointer to a `device_ops` struct
   - A name string (just a `char *`)

3. Implement two concrete operation tables:
   - `serial_ops`: `read` prints "serial read: N bytes" and returns N,
     `write` prints "serial write: N bytes" and returns N
   - `null_ops`: `read` always returns 0 (no data),
     `write` silently discards and returns N (like `/dev/null`)

4. Write a `main()` that:
   - Creates two `struct device` instances, one pointing at each ops table
   - Calls `read` and `write` through each device using the same call site
     (i.e., a helper function that takes a `struct device *` and calls through
     `dev->ops->read` and `dev->ops->write`)
   - Demonstrates that the same call produces different behavior depending on
     which ops table the device points at

## What to notice

- The call site (`dev->ops->read(...)`) doesn't know or care which implementation
  runs — that's the polymorphism
- Swapping behavior means changing which ops struct the device points at, not
  changing any call sites
- This is exactly how `struct file_operations` works in the kernel

## Kernel connection

When you open a file in Linux, the VFS sets `file->f_op` to point at the
`file_operations` table registered by whatever driver or filesystem owns that file.
Every subsequent `read()` syscall goes through `file->f_op->read`. A read from
an ext4 file, a serial port, and `/dev/null` all go through the same VFS call
site — different behavior comes entirely from which ops table `f_op` points at.

## Building

```bash
gcc -Wall -o function_pointers main.c
./function_pointers
```