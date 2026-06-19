# Progress

## Environment

- `linux-v2.6.34/`: shallow clone of `v2.6.34` — read-only reference, never built
- `linux-v6.18/`: shallow clone of `v6.18` from Linus's mainline tree (`torvalds/linux.git`)
  — built successfully with native Debian toolchain. `bzImage` produced.
  `compile_commands.json` not yet generated.
- KVM not available (`/dev/kvm` absent) — QEMU uses TCG. Nested virtualization
  to be enabled via `xe vm-param-set uuid=<uuid> platform:exp-nested-hvm=true` on the
  XCP-ng host (Dell R730) when VM is powered down for RAM upgrade.
- Neovim: cscope not yet set up for `linux-v2.6.34/`; clangd/LSP not yet set up
  for `linux-v6.18/`

## VM / boot environment — built this session

Full hand-rolled boot pipeline now exists and works end-to-end (kernel → busybox →
custom init → networked login shell). Built by hand deliberately, as a learning
exercise mirroring real init systems, rather than using busybox's own `init` applet
or a meta-build system like Buildroot.

- **Build pipeline** (`vm/Makefile` + `vm/mk/{busybox,rootfs,initramfs}.mk`): busybox
  cloned/configured/built statically (config captured as `vm/configs/busybox.defconfig`)
  → staged into `vm/rootfs/` from `vm/overlay/` (hand-authored static content, copied
  in one shot via a recursive-wildcard dependency list) plus busybox's own
  `make install` (generates the applet symlinks correctly, after an earlier attempt
  using the runtime `--install` flag was found to bake in absolute host paths) →
  packaged into `vm/initramfs.cpio.gz` via `vm/scripts/build-initramfs`, a
  `fakeroot`-wrapped script (chowns the staged tree to root:root before archiving,
  without the build itself needing real root).
- **Mini init system** (`vm/overlay/`): `/init` mounts proc/sys/devtmpfs, runs
  `/etc/init.d/{10-filesystems,20-hostname,21-network}.sh` (via `functions.sh`'s
  sysvinit-style `action`/`[ OK ]` helper), then itself `exec`s into `setsid cttyhack
  /bin/sh --login` — PID 1's own process image becomes the login shell. No separate
  login/authentication step, deliberately — single-user dev VM, no real users to
  authenticate, so `getty`/`login`/`/etc/shadow` would add friction with no benefit.
- **Networking**: `21-network.sh` brings up `eth0` via `udhcpc`, using busybox's own
  `examples/udhcp/simple.script` (copied to `/usr/share/udhcpc/default.script` — the
  real busybox-default path, confirmed against busybox's own docs). Gets a NAT'd
  `10.0.2.x` address from QEMU's slirp networking, not a real LAN address —
  `scripts/run-qemu` doesn't configure bridged networking, no concrete need yet.
- **`scripts/run-qemu`**: explicit `-netdev user` + `-device virtio-net-pci,...,
  romfile=""` (kills the iPXE/SeaBIOS banner noise that came from the implicit
  default NIC), `-serial stdio` + a separate `-monitor telnet:127.0.0.1:55555,
  server,nowait` so the VM can always be killed (`quit` in the monitor) regardless
  of guest state. Note `Ctrl-A x` no longer works since serial/monitor aren't
  multiplexed onto one stream anymore — use the monitor telnet session instead.
- Considered and deliberately deferred (no concrete need yet, not gaps to fix):
  real multi-user/login support; `/lib/modules` scaffolding (nothing to load until
  there's an actual module); bridged networking, NFS-mount-into-guest, or
  virtio-9p/virtfs host↔guest file sharing. If/when host↔guest sharing is actually
  needed, virtio-9p is the recommended path over NFS — kernel already has
  `CONFIG_9P_FS`/`CONFIG_NET_9P_VIRTIO` enabled, and it avoids NFSv3's
  rpcbind/dynamic-port issues under QEMU's NAT.

## Next steps

1. Set up `ctags`/`cscope` navigation for both kernel trees (see "Navigating the
   kernel source trees" in `CLAUDE.md`): `linux-v2.6.34/` already has `tags`/
   `cscope.out`, just needs the file manifest; `linux-v6.18/` needs `ctags`,
   `cscope`, and the manifest, all excluding build artifacts (`.o`/`.cmd`/`.a`/
   `.ko`/`vmlinux*`/`Module.symvers`/etc.)
2. Rebuild `linux-v6.18/` using an external build directory (`make O=<dir> ...`)
   instead of in-tree, so the source tree stays permanently clean — 32 cores
   available, should be quick. Remember `scripts/run-qemu` currently hardcodes
   `linux-v6.18/arch/x86/boot/bzImage`; that path moves to
   `<builddir>/arch/x86/boot/bzImage` once this lands.
3. Generate `compile_commands.json` against the new external build dir (not the
   old in-tree build — no point generating it twice)
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
