#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_message() {
    local level=$1
    local message=$2
    local color=""
    case $level in
        info) color="${GREEN}" ;;
        warning) color="${YELLOW}" ;;
        error) color="${RED}" ;;
        step) color="${BLUE}" ;;
    esac
    echo -e "${color}${message}${NC}"
}

# Determine install directory based on sudo/permissions
get_install_dir() {
    if [[ $EUID -eq 0 ]]; then
        echo "/usr/local/bin"
    elif [[ -n "${SIMP_INSTALL_DIR:-}" ]]; then
        echo "$SIMP_INSTALL_DIR"
    elif [[ -n "${XDG_BIN_DIR:-}" ]]; then
        echo "$XDG_BIN_DIR"
    elif [[ -d "$HOME/.local/bin" ]] || mkdir -p "$HOME/.local/bin" 2>/dev/null; then
        echo "$HOME/.local/bin"
    else
        echo "$HOME/bin"
    fi
}

INSTALL_DIR=$(get_install_dir)
REPO_URL="https://raw.githubusercontent.com/SebastiaanWouters/simp/main/simp.sh"
BIN_NAME="simp"

main() {
    print_message step "Installing simp..."

    # Create install directory if needed
    if [[ ! -d "$INSTALL_DIR" ]]; then
        print_message info "Creating $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
    fi

    # Download simp.sh
    print_message info "Downloading simp..."
    if command -v curl &>/dev/null; then
        curl -fsSL "$REPO_URL" -o "$INSTALL_DIR/$BIN_NAME"
    elif command -v wget &>/dev/null; then
        wget -qO "$INSTALL_DIR/$BIN_NAME" "$REPO_URL"
    else
        print_message error "Neither curl nor wget found. Please install one and try again."
        exit 1
    fi

    # Make executable
    chmod +x "$INSTALL_DIR/$BIN_NAME"

    # Verify installation
    if [[ -x "$INSTALL_DIR/$BIN_NAME" ]]; then
        print_message info "✓ Installed simp to $INSTALL_DIR/$BIN_NAME"
    else
        print_message error "Installation failed"
        exit 1
    fi

    # Check if install dir is in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        print_message warning "Add $INSTALL_DIR to your PATH:"
        
        shell_name=$(basename "${SHELL:-bash}")
        case $shell_name in
            zsh)
                echo "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.zshrc"
                echo "  source ~/.zshrc"
                ;;
            bash)
                echo "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.bashrc"
                echo "  source ~/.bashrc"
                ;;
            fish)
                echo "  fish_add_path $INSTALL_DIR"
                ;;
            *)
                echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
                ;;
        esac
    fi

    print_message info "Done! Run 'simp --help' to get started."
}

main "$@"
