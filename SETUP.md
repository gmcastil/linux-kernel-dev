# Setting Up a Development Environment

## Setting Up the Kernel Source Trees

Setting up the project is done by running the `scripts/setup` which performs a
number of useful tasks. First, it obtains shallow clones of the legacy and
modern kernel trees, and then runs the `cscope` and `tags` targets for each of
them. It also creates a `.file-manifest.txt` which allows coding assistants to
avoid having to recursively run `find` or things like that. Once the project
is set up, it is helpful to create a `compile_commands.json` for the modern
kernel. The legacy kernel will not typically build on modern Linux systems, so
we just use the `tags` and `cscope` output products for navigation and symbol
lookup.

Once that's completed, run the following to build the kernel and then create
the `compile_commands.json` file:

```bash
cd linux-v6.18
make defconfig
make -j$(nproc) O=build/linux-v6.18
make compile_commands.json
```
