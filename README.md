# simp

A loop around [Amp](https://ampcode.com) that executes a prompt until finish criteria is met.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/SebastiaanWouters/simp/main/install.sh | bash
```

For system-wide installation:
```bash
curl -fsSL https://raw.githubusercontent.com/SebastiaanWouters/simp/main/install.sh | bash -s -- --system
```

## Usage

Interactive mode:
```bash
simp
```

With arguments:
```bash
simp --max 10 --prompt "implement the next feature" --finish "all tests pass"
```

### Options

- `--max <n>` - Maximum iterations (1-25)
- `--prompt <text>` - Prompt to execute each iteration
- `--finish <text>` - Finish criteria to check after each iteration

## Building from source

Requires [Zig](https://ziglang.org/download/):

```bash
zig build -Doptimize=ReleaseFast
```

Binary will be at `zig-out/bin/simp`.
