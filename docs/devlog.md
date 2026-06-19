# Progress

## Environment

- `linux-v2.6.34/`: shallow clone of `v2.6.34` — read-only reference, never built
- `linux-v6.18/`: shallow clone of `v6.18` from Linus's mainline tree (`torvalds/linux.git`)
  — built successfully with native Debian toolchain. `bzImage` produced.
  `compile_commands.json` not yet generated.
- KVM not available (`/dev/kvm` absent) — QEMU uses TCG. Nested virtualization
  to be enabled via `xe vm-param-set uuid=<uuid> platform:exp-nested-hvm=true` on the
  XCP-ng host (Dell R730) when VM is powered down for RAM upgrade.
- Storage is NFS-mounted (`nostromo.lab.local:/srv/nfs4/storage`), not local disk —
  worth remembering when anything involving lots of small file I/O (ctags/cscope
  generation over ~90,000 files) feels slower than expected. Plenty of space
  (3.9TB free), just not local-disk-fast.
- Neovim: cscope not yet set up for `linux-v2.6.34/`; clangd/LSP not yet set up
  for `linux-v6.18/`

## VM / boot environment

Full hand-rolled boot pipeline exists and works end-to-end (kernel → busybox →
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
- `vm/`'s stamp files live flat in `vm/` (not nested under `vm/rootfs/`, which would
  leak build-tracking artifacts into the actual packaged initramfs). A dedicated
  `vm/.stamps/` subdirectory was considered and deliberately deferred — not worth it
  until the flat layout actually becomes annoying.

## `scripts/setup` — rewritten this session

Went from a rough first draft to a correct, idempotent script. Notable fixes, in
case any of these classes of bug recur elsewhere:

- The kbuild target is `tags`, not `ctags` (`ctags`/`cscope`/`gtags`/`TAGS` are the
  actual `Makefile`-defined targets — confirmed directly against
  `linux-v6.18/Makefile`). `make ctags` had been silently broken since the first
  draft of this script.
- Hit a real, classic bash gotcha: `set -e`/`set +e` inside a function has **no
  effect at all** when that function is called as the condition of `if`/`!` (e.g.
  `if ! some_func; then ...`) — bash suppresses `errexit` checking for the entire
  function call in that context, confirmed empirically. Replaced with explicit
  `cmd || { log_err ...; return 1; }` per step, which sidesteps the issue entirely
  rather than working around it with a subshell.
- The two kernel trees now provision in parallel (backgrounded `setup_kernel_repo`
  calls, each `wait`ed on by its own captured PID so `$?` is individually
  attributable per tree, both always waited on before deciding whether to exit
  non-zero — avoids leaving an orphaned background job if one side fails).
- Script is now idempotent: checks for `linux-${tag}/` before cloning rather than
  letting `git clone` fail against an existing directory. Replaces a manual
  "comment out the failure check" hack used during iteration.
- Generates `tags`, `cscope.out`/`cscope.files`, and `.file-manifest.txt`
  (`find . -path './.git' -prune -o -type f -print`) for both trees.
- A long apparent "make tags/cscope leaves no files" mystery turned out to be
  no bug at all — `ctags`/`cscope` over ~90,000 files on NFS storage just takes
  a while; checks for output files were happening before the process had finished.
  Confirmed via `ps` that `make tags` was still actively running, not failed.
- Confirmed completed: the run finished and `tags`/`cscope.out` landed correctly
  for both trees. Ctags/cscope navigation setup is genuinely done.

## Repo build architecture — decided this session

- Ownership boundaries: `scripts/setup` owns provisioning the kernel trees;
  `linux-v6.18/`'s own kbuild owns turning source into a bootable image;
  `vm/Makefile` owns busybox/rootfs/initramfs; `scripts/run-qemu` owns launching
  QEMU (a consumer of both the kernel image and the initramfs — correctly stays at
  the repo-level `scripts/`, not moved into `vm/scripts/`, since it isn't owned by
  the VM-build subsystem alone).
- The root `Makefile` (which only ever did a thin `initramfs:` passthrough to
  `vm/Makefile` plus a `clean:` that dangerously also did `rm -rf linux-*`) has
  been **deleted entirely** — concluded it wasn't earning its keep, and the
  `rm -rf linux-*` risk goes away with it. No root-level `make` surface exists
  anymore; build each piece directly (`./scripts/setup`, `cd vm && make
  initramfs`, `cd linux-v6.18 && make ...`). Revisit only if a *real* felt need
  to compose builds shows up later.
- **Important finding for the upcoming O= migration**: `scripts/tags.sh` writes
  `tags`/`cscope.out`/`cscope.files` as plain relative filenames with no
  anchoring to `$(srctree)` (confirmed by reading the script directly). Since
  `make O=<dir>` re-execs with cwd in the build dir, running `make O=<dir>
  tags`/`cscope` would relocate those files away from the kernel root, breaking
  both Neovim's lookup convention and CLAUDE.md's documented navigation rules.
  **Conclusion: never pass `O=` to the `tags`/`cscope`/manifest steps.** Only the
  actual kernel build (`defconfig`, `-j$(nproc)`) should use it.
  `scripts/setup` already does the right thing (no `O=` anywhere in it) and
  needs zero changes when the O= migration happens.

## CLAUDE.md updates this session

- Added explicit guidance: `.file-manifest.txt` must only ever be `grep`ped for a
  specific name/pattern, never `Read` in full — these run tens of thousands of
  lines / multi-MB.
- Added the same guidance for the `tags`/`cscope.out` databases, which turned out
  to be far larger (modern tree's `tags` file can reach ~1GB, given kbuild's own
  `--fields=+iaS --extras=+fq` ctags defaults). Worth generating regardless —
  primarily for Neovim navigation, only secondarily for token economy — just
  always query (`cscope -d -L1`/`grep`), never read either file whole.

## Next steps

1. Rebuild `linux-v6.18/` using an external build directory (`make O=<dir> ...`)
   instead of in-tree, so the source tree stays permanently clean — 32 cores
   available, should be quick. Remember `scripts/run-qemu` currently hardcodes
   `linux-v6.18/arch/x86/boot/bzImage`; that path moves to
   `<builddir>/arch/x86/boot/bzImage` once this lands. Do **not** pass `O=` to
   the `tags`/`cscope`/manifest steps (see finding above) — those stay exactly
   as `scripts/setup` already runs them.
2. Generate `compile_commands.json` against the new external build dir (not the
   old in-tree build — no point generating it twice).
3. ~~Complete exercise 01 (function pointers — `exercises/01-function-pointers/`).~~ Done.
4. Copy `linux-v6.18/.clang-format` to the repo root so conform.nvim's
   `clang_format` formatter (no custom `args`, so it already respects
   file-based style discovery) picks up kernel style automatically. Needs a
   fresh nvim session to take effect. Once active, run it over
   `exercises/01-function-pointers/main.c` to finish the kernel-style cleanup
   started this session — confirm it fixes `main()`'s brace placement (still
   on the same line as the signature), `main()`'s empty `()` → `(void)`, and
   the space-before-paren on every function definition (`serial_read (` →
   `serial_read(`), none of which got caught by the manual brace-placement
   edits already made to the other functions.
5. Move to chapter 2.

## Chapter progress

| Chapter | Status | Notes                |
|---------|--------|----------------------|
| Ch 01   | Done   | `book-notes/ch01.md` |

## Exercises

| Exercise                         | Status  |
|----------------------------------|---------|
| 01 — function pointers / vtables | Done    |