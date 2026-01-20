#!/bin/bash

set -e

MAX_ITERATIONS=10
PROMPT=""
FINISH=""
CONFIG_FILE=""

show_help() {
    cat << 'EOF'
simp - Simple iterative prompt runner

Usage: simp [OPTIONS]

Options:
    --prompt <text>        The prompt to run each iteration
    --finish <condition>   The condition to check for completion
    --max-iteration <n>    Maximum iterations (default: 10)
    --file <path>          YAML config file with prompt/finish/max-iterations
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
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -n "$CONFIG_FILE" ]]; then
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Error: Config file not found: $CONFIG_FILE"
        exit 1
    fi
    
    FILE_PROMPT=$(grep -E '^prompt:' "$CONFIG_FILE" | sed 's/^prompt:[[:space:]]*//')
    FILE_FINISH=$(grep -E '^finish:' "$CONFIG_FILE" | sed 's/^finish:[[:space:]]*//')
    FILE_MAX_ITERATIONS=$(grep -E '^max-iterations:' "$CONFIG_FILE" | sed 's/^max-iterations:[[:space:]]*//')
    
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

for ((i=1; i<=MAX_ITERATIONS; i++)); do
    echo "=== Iteration $i/$MAX_ITERATIONS ==="
    
    echo "Running prompt..."
    docker sandbox run claude --print "$PROMPT"
    
    echo "Checking finish condition..."
    CHECK_PROMPT="Check if the following condition is satisfied: ${FINISH}. If, and only if, the condition is satisfied, output ONLY <promise>COMPLETED</promise>. Otherwise, output ONLY <promise>PENDING</promise>."
    
    OUTPUT=$(docker sandbox run claude --print "$CHECK_PROMPT")
    
    if echo "$OUTPUT" | grep -q '<promise>COMPLETED</promise>'; then
        echo "=== COMPLETED at iteration $i ==="
        exit 0
    fi
    
    echo "Condition not satisfied, continuing..."
done

echo "=== Max iterations ($MAX_ITERATIONS) reached without completion ==="
exit 1
