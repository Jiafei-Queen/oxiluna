# oxiluna

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Rust 2024](https://img.shields.io/badge/rust-2024-orange.svg)](https://www.rust-lang.org/)
[![Lua 5.4](https://img.shields.io/badge/lua-5.4-blue.svg)](https://www.lua.org/versions.html#5.4)

A tiny **Lua‑to‑Rust** build helper. It lets you write a Lua entry‑point (and optional Lua modules) and generates a small Rust binary that embeds a Lua interpreter (via the `mlua` crate) and executes the supplied scripts.

### How it works
- [x] **Generate**: Creates `src/main.rs` with embedded Lua glue code.
- [x] **Bundle**: Copies Lua modules into `src/lua/`.
- [x] **Embed**: Embed Lua src into Rust binary at compile time (via `include_str!`)
- [x] **Compile**: Invokes `cargo build --release`.
- [x] **Export**: Delivers a standalone binary to your current path.

## Features
- Detects the host platform (Unix/Windows) and uses the appropriate shell commands.
- Supports shebang stripping so scripts can be run directly.
- Automatically copies Lua sources into the generated project structure.
- Optionally targets a custom Rust compilation target (`-t`).
- Allows specifying an output filename (`-o`).

## Prerequisites
- Rust toolchain (`cargo` and `rustc`).
- A recent version of the `mlua` crate (handled by `Cargo.toml`).
- `fs.lua` provides a cross-platform fs operation via shell & ctl-utils

## Quickstart

### Configuration
Before running the script, you must set the `OXILUNA_HOME` environment variable to the directory where you cloned this repository:

- Unix/macOS: `export OXILUNA_HOME=/path/to/oxiluna`

- Windows (CMD): `set OXILUNA_HOME=C:\path\to\oxiluna`

```bash
git clone "https://github.com/Jiafei-Queen/oxiluna.git"
cd oxiluna

# Basic usage: <script.lua> [module.lua ...] [-o <output>] [-t <target>]
lua oxiluna.lua test.lua fs.lua -o myprogram
```
- `test.lua` is the entry‑point script.
- Any additional Lua files are passed as *modules* and will be bundled.
- `-o` sets the name of the produced executable (default is the entry script name).
- `-t` forwards a custom `--target` flag to `cargo`.

The helper performs the following steps:
1. Generates `src/main.rs` with embedded Lua loading code.
2. Copies the Lua files into `src/lua/`.
3. Runs `cargo build --release` (optionally with the target).
4. Copies the compiled binary to the current working directory.

## Example
```bash
# Create a simple Lua script
cat > hello.lua <<'EOF'
print('Hello, oxiluna!')
EOF

# Build and run
./oxiluna.lua hello.lua -o hello
./hello
# → Hello, oxiluna!
```

## Contributing
Feel free to open issues or submit pull requests. Please keep the code cross‑platform and avoid adding heavyweight dependencies.