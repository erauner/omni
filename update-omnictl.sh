#!/bin/bash

# Update omnictl to the latest version
# Usage: ./update-omnictl.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Detect OS and architecture
detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    # Map architecture names
    case "$arch" in
        x86_64)
            arch="amd64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
    
    # Map OS names
    case "$os" in
        darwin|linux)
            ;;
        *)
            print_error "Unsupported OS: $os"
            exit 1
            ;;
    esac
    
    echo "${os}-${arch}"
}

# Get latest version from GitHub
get_latest_version() {
    local latest_url="https://api.github.com/repos/siderolabs/omni/releases/latest"
    local version=$(curl -s "$latest_url" | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')
    
    if [ -z "$version" ]; then
        print_error "Failed to fetch latest version"
        exit 1
    fi
    
    echo "$version"
}

# Get current installed version
get_current_version() {
    if command -v omnictl &> /dev/null; then
        omnictl --version 2>/dev/null | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^v//'
    else
        echo "not_installed"
    fi
}

# Download and install omnictl
install_omnictl() {
    local version=$1
    local platform=$2
    local install_dir="$HOME/bin"
    local binary_name="omnictl-${platform}"
    local download_url="https://github.com/siderolabs/omni/releases/download/v${version}/${binary_name}"
    local temp_file="/tmp/omnictl-${version}"
    
    print_info "Downloading omnictl v${version} for ${platform}..."
    
    # Create bin directory if it doesn't exist
    mkdir -p "$install_dir"
    
    # Download binary
    if ! curl -Lo "$temp_file" "$download_url"; then
        print_error "Failed to download omnictl"
        exit 1
    fi
    
    # Make executable
    chmod +x "$temp_file"
    
    # Verify download
    if ! "$temp_file" --version &> /dev/null; then
        print_error "Downloaded binary verification failed"
        rm -f "$temp_file"
        exit 1
    fi
    
    # Move to installation directory
    mv "$temp_file" "$install_dir/omnictl"
    
    print_info "Installed omnictl to $install_dir/omnictl"
    
    # Check if bin directory is in PATH
    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        print_warn "$install_dir is not in your PATH"
        
        # Detect shell and provide instructions
        if [ -n "$ZSH_VERSION" ]; then
            shell_rc="$HOME/.zshrc"
        elif [ -n "$BASH_VERSION" ]; then
            shell_rc="$HOME/.bashrc"
        else
            shell_rc="your shell configuration file"
        fi
        
        print_info "Add the following line to $shell_rc:"
        echo "export PATH=\"\$HOME/bin:\$PATH\""
        
        # Add to PATH for current session
        export PATH="$HOME/bin:$PATH"
    fi
}

# Main script
main() {
    print_info "Checking for omnictl updates..."
    
    # Detect platform
    platform=$(detect_platform)
    print_info "Detected platform: $platform"
    
    # Get versions
    current_version=$(get_current_version)
    latest_version=$(get_latest_version)
    
    if [ "$current_version" == "not_installed" ]; then
        print_info "omnictl is not installed"
        print_info "Latest version available: v${latest_version}"
        install_omnictl "$latest_version" "$platform"
    elif [ "$current_version" == "$latest_version" ]; then
        print_info "omnictl is already up to date (v${current_version})"
        exit 0
    else
        print_info "Current version: v${current_version}"
        print_info "Latest version: v${latest_version}"
        print_info "Updating omnictl..."
        install_omnictl "$latest_version" "$platform"
    fi
    
    # Verify installation
    installed_version=$(omnictl --version 2>/dev/null | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^v//')
    if [ "$installed_version" == "$latest_version" ]; then
        print_info "Successfully installed omnictl v${latest_version}"
        
        # Show the actual path being used
        print_info "Using omnictl at: $(which omnictl)"
    else
        print_error "Installation verification failed"
        exit 1
    fi
}

# Run main function
main