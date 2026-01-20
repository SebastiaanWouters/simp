# simp

A simple iterative prompt runner for Claude sandbox.

## Installation

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/SebastiaanWouters/simp@main/install.sh | bash
```

Or with sudo for system-wide installation:

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/SebastiaanWouters/simp@main/install.sh | sudo bash
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

Create a YAML config file:

```yaml
prompt: |
  1. Run `tk ready` to find the next ticket
  2. Run `tk start <id>` to mark it in progress
  3. Implement the ticket
  4. Run tests to verify
  5. Run `tk close <id>` when done

finish: tk ready shows no tickets

max-iterations: 20
```

Then run:

```bash
simp --file config.yaml
```

The agent loops until the finish condition is met or max iterations reached.

## License

MIT
