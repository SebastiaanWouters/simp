#!/bin/bash

set -e

MAX_ITERATIONS=10
PROMPT=""
FINISH=""
CONFIG_FILE=""
USE_SANDBOX=false

show_help() {
    cat << 'EOF'
simp - Simple iterative prompt runner

Usage: simp [OPTIONS]

Options:
    --prompt <text>        The prompt to run each iteration
    --finish <condition>   The condition to check for completion
    --max-iteration <n>    Maximum iterations (default: 10)
    --file <path>          YAML config file with prompt/finish/max-iterations
    --sandbox              Use docker sandbox instead of --dangerously-skip-permissions
    --help, -h             Show this help message

Example:
    simp --prompt "Fix the failing tests" --finish "All tests pass"
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            ;;
        --max-iteration)
            MAX_ITERATIONS="$2"
            shift 2
            ;;
        --prompt)
            PROMPT="$2"
            shift 2
            ;;
        --finish)
            FINISH="$2"
            shift 2
            ;;
        --file)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --sandbox)
            USE_SANDBOX=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

parse_yaml_value() {
    local file="$1"
    local key="$2"
    local line_num value_part result=""
    
    line_num=$(grep -n "^${key}:" "$file" | head -1 | cut -d: -f1)
    [[ -z "$line_num" ]] && return
    
    value_part=$(sed -n "${line_num}p" "$file" | sed "s/^${key}:[[:space:]]*//")
    
    if [[ "$value_part" == "|" || "$value_part" == "|-" || "$value_part" == "|+" ]]; then
        local next_line=$((line_num + 1))
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]+ ]]; then
                [[ -n "$result" ]] && result+=$'\n'
                result+="${line#  }"
            else
                break
            fi
        done < <(tail -n "+$next_line" "$file")
    else
        result="$value_part"
    fi
    
    printf '%s' "$result"
}

if [[ -n "$CONFIG_FILE" ]]; then
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Error: Config file not found: $CONFIG_FILE"
        exit 1
    fi
    
    FILE_PROMPT=$(parse_yaml_value "$CONFIG_FILE" "prompt")
    FILE_FINISH=$(parse_yaml_value "$CONFIG_FILE" "finish")
    FILE_MAX_ITERATIONS=$(parse_yaml_value "$CONFIG_FILE" "max-iterations")
    
    [[ -z "$PROMPT" && -n "$FILE_PROMPT" ]] && PROMPT="$FILE_PROMPT"
    [[ -z "$FINISH" && -n "$FILE_FINISH" ]] && FINISH="$FILE_FINISH"
    [[ -n "$FILE_MAX_ITERATIONS" ]] && MAX_ITERATIONS="$FILE_MAX_ITERATIONS"
fi

if [[ -z "$PROMPT" ]]; then
    echo "Error: --prompt is required"
    exit 1
fi

if [[ -z "$FINISH" ]]; then
    echo "Error: --finish is required"
    exit 1
fi

ESCAPED_PROMPT=$(printf '%q' "$PROMPT")
ESCAPED_FINISH=$(printf '%q' "$FINISH")

run_claude_with_retry() {
    local max_retries=3
    local delay=2
    local attempt=1
    local output
    
    while ((attempt <= max_retries)); do
        if output=$($CLAUDE_CMD --print "$@" 2>&1); then
            printf '%s' "$output"
            return 0
        fi
        echo "Attempt $attempt failed, retrying in ${delay}s..." >&2
        sleep "$delay"
        delay=$((delay * 2))
        ((attempt++))
    done
    
    echo "Error: All $max_retries attempts failed" >&2
    return 1
}

if [[ "$USE_SANDBOX" == true ]]; then
    CLAUDE_CMD="docker sandbox run claude"
else
    CLAUDE_CMD="claude --dangerously-skip-permissions"
fi

for ((i=1; i<=MAX_ITERATIONS; i++)); do
    echo "=== Iteration $i/$MAX_ITERATIONS ==="
    
    echo "Running prompt..."
    if ! run_claude_with_retry "$PROMPT"; then
        echo "Warning: Prompt execution failed, skipping to next iteration..."
        continue
    fi
    
    echo "Checking finish condition..."
    CHECK_PROMPT="Check if the following condition is satisfied: ${FINISH}. If, and only if, the condition is satisfied, output ONLY <promise>COMPLETED</promise>. Otherwise, output ONLY <promise>PENDING</promise>."
    
    if ! OUTPUT=$(run_claude_with_retry "$CHECK_PROMPT"); then
        echo "Warning: Finish check failed, assuming PENDING..."
        continue
    fi
    
    if echo "$OUTPUT" | grep -q '<promise>COMPLETED</promise>'; then
        echo "=== COMPLETED at iteration $i ==="
        exit 0
    fi
    
    echo "Condition not satisfied, continuing..."
done

echo "=== Max iterations ($MAX_ITERATIONS) reached without completion ==="
exit 1
