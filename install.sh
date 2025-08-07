#!/usr/bin/env bash

# Configuration variables
CHAOTIC_AUR_KEY="3056513887B78AEB"
CHAOTIC_AUR_KEYSERVER="keyserver.ubuntu.com"
CHAOTIC_AUR_MIRROR="https://eu.mirror.chaotic.cx/\$repo/\$arch"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status messages
status() {
    echo -e "${BLUE}[*]${NC} $1"
}

# Function to print success messages
success() {
    echo -e "${GREEN}[+]${NC} $1"
}

# Function to print warning messages
warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Function to print error messages and exit
error() {
    echo -e "${RED}[-]${NC} $1" >&2
    exit 1
}

# Check for internet connectivity with retries
check_internet() {
    local max_attempts=3
    local attempt=1
    
    status "Checking for internet connectivity..."
    
    while [ $attempt -le $max_attempts ]; do
        if ping -c 1 -W 3 archlinux.org &> /dev/null; then
            success "Internet connected."
            return 0
        fi
        
        warning "Attempt $attempt/$max_attempts failed. Retrying in 3 seconds..."
        sleep 3
        ((attempt++))
    done
    
    error "No internet connection after $max_attempts attempts. Please connect to the internet and try again."
}

# Run command with error handling
run_command() {
    local cmd="$1"
    local error_msg="$2"
    
    status "Executing: $cmd"
    if ! eval "$cmd"; then
        error "$error_msg"
    fi
}

# Add Chaotic-AUR repository
add_chaotic_aur() {
    status "Setting up Chaotic-AUR repository..."
    
    if grep -q "chaotic-aur" /etc/pacman.conf; then
        warning "Chaotic-AUR repository already exists in pacman.conf."
        return 0
    fi
    
    run_command \
        "sudo pacman-key --recv-key $CHAOTIC_AUR_KEY --keyserver $CHAOTIC_AUR_KEYSERVER" \
        "Failed to receive Chaotic-AUR key."
    
    run_command \
        "sudo pacman-key --lsign-key $CHAOTIC_AUR_KEY" \
        "Failed to sign Chaotic-AUR key."
    
    run_command \
        "echo -e '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' | sudo tee -a /etc/pacman.conf > /dev/null" \
        "Failed to append Chaotic-AUR to pacman.conf."
    
    run_command \
        "echo 'Server = $CHAOTIC_AUR_MIRROR' | sudo tee /etc/pacman.d/chaotic-mirrorlist > /dev/null" \
        "Failed to create chaotic-mirrorlist."
    
    run_command \
        "sudo pacman -Syy" \
        "Failed to refresh pacman databases."
    
    success "Chaotic-AUR repository configured successfully."
}

# Install packages from file
install_packages() {
    local file="$1"
    local installer="$2"
    
    if [ ! -f "$file" ]; then
        warning "Package list '$file' not found. Skipping."
        return 1
    fi
    
    status "Installing packages from '$file' using $installer..."
    
    # Read package file, skip empty lines and comments
    local packages=()
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        packages+=("$line")
    done < "$file"
    
    if [ ${#packages[@]} -eq 0 ]; then
        warning "No valid packages found in '$file'."
        return 1
    fi
    
    # Install all packages at once for better performance
    if ! $installer -S --noconfirm "${packages[@]}"; then
        warning "Some packages failed to install. Trying one by one..."
        
        # Fallback to individual installation
        for pkg in "${packages[@]}"; do
            status "Installing $pkg..."
            if ! $installer -S --noconfirm "$pkg"; then
                warning "Failed to install $pkg"
            fi
        done
    fi
    
    success "Package installation completed."
}

# Copy directory contents with error handling
copy_files() {
    local src="$1"
    local dest="$2"
    local desc="$3"
    
    if [ ! -d "$src" ]; then
        warning "Source directory '$src' not found. Skipping $desc."
        return 1
    fi
    
    status "Copying $desc to $dest..."
    mkdir -p "$dest" || {
        warning "Failed to create $dest. Skipping $desc."
        return 1
    }
    
    if cp -r "$src"/* "$dest"/; then
        success "$desc copied successfully."
    else
        warning "Some errors occurred while copying $desc."
    fi
}

# Setup zsh configuration
setup_zsh() {
    if ! command -v zsh &> /dev/null; then
        status "Installing zsh..."
        run_command \
            "sudo pacman -S --noconfirm zsh" \
            "Failed to install zsh."
        success "zsh installed."
    else
        warning "zsh is already installed."
    fi
    
    if [ "$SHELL" != "$(command -v zsh)" ]; then
        status "Changing default shell to zsh..."
        if chsh -s "$(command -v zsh)"; then
            success "Default shell changed to zsh. Please log out and back in for changes to take effect."
        else
            warning "Failed to change default shell to zsh."
        fi
    else
        warning "Default shell is already zsh."
    fi
    
    if [ -f ".zshrc" ]; then
        status "Setting up .zshrc..."
        if cp .zshrc ~/.zshrc; then
            success ".zshrc configured."
        else
            warning "Failed to copy .zshrc."
        fi
    else
        warning ".zshrc file not found. Skipping."
    fi
}

# Main installation function
install_hypr_nord() {
    check_internet
    
    # System update
    run_command \
        "sudo pacman -Syu --noconfirm" \
        "System update failed."
    
    # Add Chaotic-AUR
    add_chaotic_aur
    
    # Install yay from Chaotic-AUR
    if ! command -v yay &> /dev/null; then
        status "Installing yay from Chaotic-AUR..."
        run_command \
            "sudo pacman -S --noconfirm yay" \
            "Failed to install yay."
        success "yay installed."
    else
        warning "yay is already installed."
    fi
    
    # Install packages
    install_packages "packages" "yay"
    
    # Copy configuration files
    copy_files "Configs" "$HOME/.config" "configuration files"
    copy_files "Theme" "$HOME/.themes" "theme files"
    copy_files "Icons" "$HOME/.icons" "icon files"
    copy_files "Fonts" "$HOME/.fonts" "font files"
    
    # Rebuild font cache
    status "Rebuilding font cache..."
    if fc-cache -fv; then
        success "Font cache rebuilt."
    else
        warning "Font cache rebuild encountered errors."
    fi
    
    # Setup zsh
    setup_zsh
    
    # Copy wallpapers
    copy_files "Wallpapers" "$HOME/Pictures" "wallpapers"
    
    success "Hyprland Nord setup completed successfully!"
}

# Execute main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_hypr_nord
fi