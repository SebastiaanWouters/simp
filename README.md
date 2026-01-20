# simp

A simple iterative prompt runner for Claude sandbox.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/SebastiaanWouters/simp/main/install.sh | bash
```

Or with sudo for system-wide installation:

```bash
curl -fsSL https://raw.githubusercontent.com/SebastiaanWouters/simp/main/install.sh | sudo bash
```

## Usage

```bash
simp --prompt "Your task" --finish "Completion condition"
```

### Options

| Option | Description |
|--------|-------------|
| `--prompt` | The prompt to run (required) |
| `--finish` | The completion condition to check (required) |
| `--max-iteration` | Maximum iterations (default: 10) |
| `--file` | Config file with prompt, finish, and max-iterations |

### Config File

Create a config file with:

```
prompt: Your task here
finish: Condition that must be satisfied
max-iterations: 10
```

Then run:

```bash
simp --file config.txt
```

## License

MIT
