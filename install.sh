#!/usr/bin/env bash
set -euo pipefail

# simp installer
# Usage: curl -fsSL https://example.com/install.sh | bash
#        curl -fsSL https://example.com/install.sh | bash -s -- --system

# Configuration
GITHUB_REPO="sebastiaanwouters/simp"
BINARY_NAME="simp"

# Colors (only if terminal supports them)
Color_Off=''
Red=''
Green=''
Dim=''
Bold_White=''
Bold_Green=''

if [[ -t 1 ]]; then
    Color_Off='\033[0m'
    Red='\033[0;31m'
    Green='\033[0;32m'
    Dim='\033[0;2m'
    Bold_White='\033[1m'
    Bold_Green='\033[1;32m'
fi

error() {
    echo -e "${Red}error${Color_Off}: $*" >&2
    exit 1
}

warn() {
    echo -e "${Red}warning${Color_Off}: $*" >&2
}

info() {
    echo -e "${Dim}$*${Color_Off}"
}

info_bold() {
    echo -e "${Bold_White}$*${Color_Off}"
}

success() {
    echo -e "${Green}$*${Color_Off}"
}

# Parse arguments
SYSTEM_INSTALL=false
VERSION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --system|-s)
            SYSTEM_INSTALL=true
            shift
            ;;
        --version|-v)
            VERSION="$2"
            shift 2
            ;;
        -*)
            error "Unknown option: $1"
            ;;
        *)
            VERSION="$1"
            shift
            ;;
    esac
done

# Detect platform
detect_platform() {
    local os arch

    case "$(uname -s)" in
        Darwin)
            os="macos"
            ;;
        Linux)
            os="linux"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            error "Windows is not supported. Please use WSL."
            ;;
        *)
            error "Unsupported operating system: $(uname -s)"
            ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64)
            arch="x86_64"
            ;;
        arm64|aarch64)
            arch="aarch64"
            ;;
        *)
            error "Unsupported architecture: $(uname -m)"
            ;;
    esac

    # Check for musl on Linux
    if [[ "$os" == "linux" ]]; then
        if ldd --version 2>&1 | grep -q musl || [[ -f /etc/alpine-release ]]; then
            arch="${arch}-musl"
        fi
    fi

    echo "${os}-${arch}"
}

# Check for required commands
check_dependencies() {
    local missing=()

    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        missing+=("curl or wget")
    fi

    if ! command -v tar >/dev/null 2>&1; then
        missing+=("tar")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required dependencies: ${missing[*]}"
    fi
}

# Download function (supports curl and wget)
download() {
    local url="$1"
    local output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl --fail --location --progress-bar --output "$output" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget --quiet --show-progress --output-document="$output" "$url"
    else
        error "Neither curl nor wget is available"
    fi
}

# Get latest version from GitHub releases
get_latest_version() {
    local url="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
    local response

    if command -v curl >/dev/null 2>&1; then
        response=$(curl -fsSL "$url" 2>/dev/null) || return 1
    else
        response=$(wget -qO- "$url" 2>/dev/null) || return 1
    fi

    # Extract tag_name from JSON (works without jq)
    echo "$response" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
}

# Determine install directory
get_install_dir() {
    if [[ "$SYSTEM_INSTALL" == "true" ]]; then
        echo "/usr/local/bin"
    else
        echo "$HOME/.local/bin"
    fi
}

# Check if we need sudo for the install directory
needs_sudo() {
    local dir="$1"

    # User install never needs sudo
    if [[ "$SYSTEM_INSTALL" != "true" ]]; then
        return 1
    fi

    # Check if directory is writable
    if [[ -w "$dir" ]] || [[ -w "$(dirname "$dir")" ]]; then
        return 1
    fi

    return 0
}

# Install the binary
install_binary() {
    local install_dir="$1"
    local binary_path="$2"
    local target="$install_dir/$BINARY_NAME"

    if needs_sudo "$install_dir"; then
        if ! command -v sudo >/dev/null 2>&1; then
            error "sudo is required for system-wide installation but is not available"
        fi
        info "Installing to $install_dir (requires sudo)..."
        sudo mkdir -p "$install_dir"
        sudo install -m 755 "$binary_path" "$target"
    else
        mkdir -p "$install_dir"
        install -m 755 "$binary_path" "$target"
    fi
}

# Convert path to tilde notation for display
tildify() {
    if [[ "$1" == "$HOME"/* ]]; then
        echo "~${1#$HOME}"
    else
        echo "$1"
    fi
}

# Add directory to PATH in shell config
setup_shell_path() {
    local bin_dir="$1"
    local shell_name
    local config_file
    local export_line="export PATH=\"$bin_dir:\$PATH\""

    # Skip if already in PATH
    if [[ ":$PATH:" == *":$bin_dir:"* ]]; then
        return 0
    fi

    shell_name=$(basename "${SHELL:-/bin/bash}")

    case "$shell_name" in
        zsh)
            config_file="$HOME/.zshrc"
            ;;
        bash)
            if [[ -f "$HOME/.bash_profile" ]]; then
                config_file="$HOME/.bash_profile"
            else
                config_file="$HOME/.bashrc"
            fi
            ;;
        fish)
            config_file="$HOME/.config/fish/config.fish"
            export_line="fish_add_path $bin_dir"
            ;;
        *)
            config_file="$HOME/.profile"
            ;;
    esac

    # Check if already configured
    if [[ -f "$config_file" ]] && grep -q "$bin_dir" "$config_file" 2>/dev/null; then
        return 0
    fi

    # Add to config file if writable
    if [[ -w "$config_file" ]] || [[ ! -f "$config_file" && -w "$(dirname "$config_file")" ]]; then
        {
            echo ""
            echo "# $BINARY_NAME"
            echo "$export_line"
        } >> "$config_file"
        info "Added $(tildify "$bin_dir") to \$PATH in $(tildify "$config_file")"
        return 0
    fi

    return 1
}

# Build from source (fallback if no prebuilt binary)
build_from_source() {
    local install_dir="$1"
    local tmp_dir

    info "Building from source..."

    # Check for zig
    if ! command -v zig >/dev/null 2>&1; then
        error "Zig is required to build from source but is not installed.
Install Zig: https://ziglang.org/download/"
    fi

    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    # Clone repo
    if command -v git >/dev/null 2>&1; then
        git clone --depth 1 "https://github.com/${GITHUB_REPO}.git" "$tmp_dir/simp" 2>/dev/null || \
            error "Failed to clone repository"
    else
        error "git is required to build from source"
    fi

    cd "$tmp_dir/simp"

    # Build
    zig build -Doptimize=ReleaseFast || error "Build failed"

    # Install
    install_binary "$install_dir" "zig-out/bin/$BINARY_NAME"
}

# Main installation flow
main() {
    echo ""
    info_bold "simp installer"
    echo ""

    check_dependencies

    local platform
    platform=$(detect_platform)
    info "Detected platform: $platform"

    local install_dir
    install_dir=$(get_install_dir)

    # Determine version
    if [[ -z "$VERSION" ]]; then
        info "Fetching latest version..."
        VERSION=$(get_latest_version) || VERSION=""
    fi

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    local installed=false

    # Try to download prebuilt binary
    if [[ -n "$VERSION" ]]; then
        local archive_name="${BINARY_NAME}-${VERSION}-${platform}.tar.gz"
        local download_url="https://github.com/${GITHUB_REPO}/releases/download/${VERSION}/${archive_name}"
        local archive_path="$tmp_dir/$archive_name"

        info "Downloading $BINARY_NAME $VERSION..."
        if download "$download_url" "$archive_path" 2>/dev/null; then
            info "Extracting..."
            if tar -xzf "$archive_path" -C "$tmp_dir" 2>/dev/null; then
                local binary_path="$tmp_dir/$BINARY_NAME"
                if [[ -f "$binary_path" ]]; then
                    chmod +x "$binary_path"
                    install_binary "$install_dir" "$binary_path"
                    installed=true
                fi
            fi
        fi
    fi

    # Fallback to building from source
    if [[ "$installed" != "true" ]]; then
        warn "No prebuilt binary available for $platform, building from source..."
        build_from_source "$install_dir"
    fi

    local exe_path="$install_dir/$BINARY_NAME"

    echo ""
    success "$BINARY_NAME was installed successfully to $(tildify "$exe_path")"

    # Check if already in PATH
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        echo ""
        info "Run '$BINARY_NAME --help' to get started"
        return 0
    fi

    # Setup PATH for user installs
    if [[ "$SYSTEM_INSTALL" != "true" ]]; then
        echo ""
        if setup_shell_path "$install_dir"; then
            info "To get started, run:"
            echo ""
            info_bold "  source ~/.$(basename "$SHELL")rc  # or restart your terminal"
            info_bold "  $BINARY_NAME --help"
        else
            echo "Manually add the directory to your \$PATH:"
            info_bold "  export PATH=\"$install_dir:\$PATH\""
            echo ""
            info "Then run:"
            info_bold "  $BINARY_NAME --help"
        fi
    fi

    echo ""
}

main "$@"
