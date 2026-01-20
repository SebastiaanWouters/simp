---
name: create-simp-config
description: Creates simp YAML config files for iterative Claude prompting. Use when asked to create a simp config, automation loop, or iterative task runner.
---

# Create Simp Config

Creates YAML configuration files for simp - the simple iterative prompt runner.

## Config File Schema

```yaml
prompt: |
  Multi-line prompt describing the task to execute each iteration.
  Can include numbered steps, commands, or instructions.

finish: Single-line condition that determines when to stop iterating

max-iterations: 10  # Optional, defaults to 10
```

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `prompt` | string | The task prompt run each iteration (use `\|` for multi-line) |
| `finish` | string | Completion condition checked after each iteration |

## Optional Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `max-iterations` | integer | 10 | Maximum iterations before giving up |

## Writing Effective Configs

### Prompts

- Use multi-line format (`|`) for complex tasks
- Include numbered steps for clarity
- Reference specific commands/tools the agent should use
- Be explicit about verification steps

### Finish Conditions

- Must be verifiable by the agent
- Reference observable state (files, command output, test results)
- Keep conditions concise and unambiguous

## Examples

### Ticket Processing Loop

```yaml
prompt: |
  1. Run `tk ready` to find the next ticket
  2. Run `tk start <id>` to mark it in progress
  3. Implement the ticket requirements
  4. Run tests to verify implementation
  5. Run `tk close <id>` when complete

finish: tk ready shows no tickets

max-iterations: 20
```

### Test Fix Loop

```yaml
prompt: |
  1. Run the test suite
  2. Identify failing tests
  3. Fix the root cause of failures
  4. Verify fixes don't break other tests

finish: All tests pass

max-iterations: 15
```

### Build Error Resolution

```yaml
prompt: |
  1. Run the build command
  2. Analyze any errors or warnings
  3. Fix the issues in the source code
  4. Re-run build to verify

finish: Build succeeds with no errors

max-iterations: 10
```

### Code Migration

```yaml
prompt: |
  1. Find the next file using deprecated API
  2. Update to use the new API
  3. Run tests for that module
  4. Commit the change

finish: No files contain deprecated API calls

max-iterations: 50
```

## Workflow

1. **Gather requirements**: Ask what task should loop and what signals completion
2. **Draft prompt**: Write clear, step-by-step instructions
3. **Define finish condition**: Identify verifiable completion state
4. **Set max-iterations**: Choose based on expected task complexity
5. **Save config**: Write to `.yaml` file in project root or appropriate location

## Running the Config

```bash
simp --file config.yaml
```

Optional flags:
- `--sandbox`: Use Docker sandbox instead of `--dangerously-skip-permissions`
- `--max-iteration N`: Override config's max-iterations
