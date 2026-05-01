# oxiluna

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Rust 2024](https://img.shields.io/badge/rust-2024-orange.svg)](https://www.rust-lang.org/)

A tiny **Lua‑to‑Rust** build helper. It lets you write a Lua entry‑point (and optional Lua modules) and generates a small Rust binary that embeds a Lua interpreter (via the `mlua` crate) and executes the supplied scripts.

## Features
- Detects the host platform (Unix/Windows) and uses the appropriate shell commands.
- Supports shebang stripping so scripts can be run directly.
- Automatically copies Lua sources into the generated project structure.
- Optionally targets a custom Rust compilation target (`-t`).
- Allows specifying an output filename (`-o`).

## Prerequisites
- Rust toolchain (`cargo` and `rustc`).
- A recent version of the `mlua` crate (handled by `Cargo.toml`).
- Unix‑like tools (`pwd`, `ls`, `mkdir`, `rm`, `cp`, `mv`) on Windows the script falls back to their equivalents.

## Very Quickstart!!!
```bash
# Basic usage: <script.lua> [module.lua ...] [-o <output>] [-t <target>]
./oxiluna.lua test.lua fs.lua -o myprogram
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