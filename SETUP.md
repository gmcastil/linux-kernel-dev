# Setting Up a Development Environment

## Setting Up the Kernel Source Trees

To get the two kernels, just run the `scripts/setup` to shallow clone the two kernel source trees.
Once they are obtained, create the navigation tags for the legacy kernel

```bash
cd linux-v2.6.34
make cscope
make tags
```

For the modern kernel, it needs to be built first

```bash
cd linux-v6.18
make defconfig
make -j$(nproc)
make compile_commands.json
```
