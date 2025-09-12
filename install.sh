#!/bin/bash

# AWS Login Script Installer
# Usage: curl -sSL https://raw.githubusercontent.com/your-repo/aws-login/main/install.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_NAME="aws-login.sh"
INSTALL_DIR="$HOME/.aws-login"
SCRIPT_URL="https://raw.githubusercontent.com/Xmaxer/aws-login/main/aws-login.sh"
ZSHRC_FILE="$HOME/.zshrc"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to create installation directory
create_install_dir() {
    print_status "Creating installation directory..."

    if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR"
        print_success "Created directory: $INSTALL_DIR"
    else
        print_status "Directory already exists: $INSTALL_DIR"
    fi
}

# Function to download the script
download_script() {
    print_status "Downloading aws-login.sh script..."

    local script_path="$INSTALL_DIR/$SCRIPT_NAME"

    if [ -f "$script_path" ]; then
        print_status "Removing existing script file..."
        rm -f "$script_path"
    fi

    if curl -sSL "$SCRIPT_URL" -o "$script_path"; then
        chmod +x "$script_path"
        print_success "Downloaded and made executable: $script_path"
    else
        print_error "Failed to download script from: $SCRIPT_URL"
        print_status "Please check your internet connection and the URL."
        exit 1
    fi
}

# Function to backup .zshrc
backup_zshrc() {
    if [ -f "$ZSHRC_FILE" ]; then
        local backup_file="${ZSHRC_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$ZSHRC_FILE" "$backup_file"
        print_success "Backed up .zshrc to: $backup_file"
    fi
}

# Function to add script to .zshrc
add_to_zshrc() {
    print_status "Adding aws-login.sh to .zshrc..."

    local script_path="$INSTALL_DIR/$SCRIPT_NAME"
    local source_line="source \"$script_path\""

    # Create .zshrc if it doesn't exist
    if [ ! -f "$ZSHRC_FILE" ]; then
        touch "$ZSHRC_FILE"
        print_status "Created .zshrc file"
    fi

    # Check if already sourced
    if grep -Fq "$source_line" "$ZSHRC_FILE"; then
        print_warning "aws-login.sh is already sourced in .zshrc"
        return 0
    fi

    # Add source line to .zshrc
    echo "" >> "$ZSHRC_FILE"
    echo "# AWS Login Script" >> "$ZSHRC_FILE"
    echo "$source_line" >> "$ZSHRC_FILE"

    print_success "Added aws-login.sh to .zshrc"
}

# Function to source the script in current session
source_script() {
    print_status "Sourcing aws-login.sh in current session..."

    local script_path="$INSTALL_DIR/$SCRIPT_NAME"

    if [ -f "$script_path" ]; then
        # shellcheck source=/dev/null
        source "$script_path"
        print_success "aws-login.sh sourced successfully"
    else
        print_error "Script not found: $script_path"
        exit 1
    fi
}

# Function to verify installation
verify_installation() {
    print_status "Verifying installation..."

    if command_exists aws-login; then
        print_success "aws-login command is available"
    else
        print_warning "aws-login command not found. You may need to restart your shell or run: source ~/.zshrc"
    fi
}

# Function to print usage instructions
print_usage() {
    echo ""
    print_success "Installation completed successfully!"
    echo ""
    echo "Usage:"
    echo "  aws-login                 # Interactive AWS login with account/role selection"
    echo ""
    echo "The script provides the following functions:"
    echo "  aws-login                 # Main interactive login function"
    echo ""
    echo "To start using the script:"
    echo "  1. Restart your terminal or run: source ~/.zshrc"
    echo "  2. Run: aws-login"
    echo ""
    echo "Note: The script requires 'fzf' and 'jq' which will be installed automatically if missing (on macOS with Homebrew)."
}

# Main installation function
main() {
    echo ""
    print_status "Starting AWS Login Script installation..."
    echo ""

    backup_zshrc
    create_install_dir
    download_script
    add_to_zshrc
    source_script
    verify_installation
    print_usage
}

# Run main function
main "$@"
