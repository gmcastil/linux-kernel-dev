# Progress

## Environment

- `linux-v2.6.34/`: shallow clone of `v2.6.34` — read-only reference, never built
- `linux-v6.18/`: shallow clone of `v6.18` from Linus's mainline tree (`torvalds/linux.git`)
  — built successfully with native Debian toolchain. `bzImage` produced.
  `compile_commands.json` not yet generated.
- KVM not available (`/dev/kvm` absent) — QEMU will use TCG. Nested virtualization
  to be enabled via `xe vm-param-set uuid=<uuid> platform:exp-nested-hvm=true` on the
  XCP-ng host (Dell R730) when VM is powered down for RAM upgrade.
- Neovim: cscope not yet set up for `linux-v2.6.34/`; clangd/LSP not yet set up
  for `linux-v6.18/`

## Next steps

1. Generate `compile_commands.json` in `linux-v6.18/` (`make compile_commands.json`)
2. Build a minimal busybox initramfs
3. Boot `linux-v6.18/` under QEMU (x86, TCG until KVM enabled on R730)
4. Complete exercise 01 (function pointers — `exercises/01-function-pointers/`)
5. Move to chapter 2

## Chapter progress

| Chapter | Status | Notes                |
|---------|--------|----------------------|
| Ch 01   | Done   | `book-notes/ch01.md` |

## Exercises

| Exercise                         | Status  |
|----------------------------------|---------|
| 01 — function pointers / vtables | Pending |
