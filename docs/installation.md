# Installation

## Prerequisites

- **Rust toolchain** (for `cargo install`): [rustup.rs](https://rustup.rs/)
- **Typst** (for rendering and validation): `cargo install typst-cli` or
  [typst.app](https://typst.app/)
- **`usage` CLI** (for shell completions): [usage.jdx.dev](https://usage.jdx.dev/)
- **`cargo-binstall`** (optional, for pre-built binaries):
  [cargo-binstall](https://github.com/cargo-bins/cargo-binstall)

---

## cargo install

```bash
cargo install typspec
```

This compiles from source. First build takes a few minutes; subsequent
updates are faster.

### Update

```bash
cargo install typspec
```

### Verify

```bash
typspec --version
typspec --help
```

---

## cargo binstall

Requires [`cargo-binstall`](https://github.com/cargo-bins/cargo-binstall).

```bash
cargo binstall typspec
```

Downloads a pre-built binary from the GitHub Release — no compilation
needed. Supports Linux, macOS, and Windows.

### Update

```bash
cargo binstall typspec
```

---

## mise

```bash
# Install via cargo (compiles from source)
mise use cargo:typspec

# Install via binstall (pre-built binary, faster)
mise use cargo-binstall:typspec
```

See [mise documentation](https://mise.jdx.dev) for managing tool
versions across projects.

---

## Build from source

```bash
git clone https://github.com/ggallovalle/typspec
cd typspec
cargo build --release
```

The binary is at `./target/release/typspec`. Add it to your `$PATH`:

```bash
# Linux / macOS
cp ./target/release/typspec ~/.local/bin/

# Or run directly
./target/release/typspec --version
```

---

## Shell completions

typspec uses the [`usage`](https://usage.jdx.dev) CLI for shell completions.

### zsh

```bash
typspec completion zsh > ~/.zsh/functions/_typspec
```

Or source it from your `.zshrc`:

```zsh
if [[ ! -f ~/.zsh/functions/_typspec ]]; then
    typspec completion zsh > ~/.zsh/functions/_typspec
fi
source ~/.zsh/functions/_typspec
```

### Other shells

```bash
typspec completion bash  # bash
typspec completion fish  # fish
typspec completion powershell  # PowerShell
```

---

## Troubleshooting

### "command not found: typspec"

After `cargo install`, ensure `~/.cargo/bin` is in your `$PATH`:

```bash
export PATH="$HOME/.cargo/bin:$PATH"
```

Add this to your shell config (`.zshrc`, `.bashrc`, etc.).

### "no typspec project found"

You need to initialize a project first:

```bash
typspec init
```

### "typst: command not found"

typspec uses Typst for rendering and validation. Install it:

```bash
cargo install typst-cli
```

### "usage CLI not found"

Shell completions require the `usage` CLI:

```bash
cargo install usage-cli
# or: mise use usage
```
