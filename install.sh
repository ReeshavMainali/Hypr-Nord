#!/bin/bash

# Function to check for internet connectivity
check_internet() {
    echo "Checking for internet connectivity..."
    ping -c 1 archlinux.org &> /dev/null
    if [ $? -eq 0 ]; then
        echo "Internet connected."
        return 0
    else
        echo "Error: No internet connection. Please connect to the internet and try again."
        return 1
    fi
}

# Main installation script
install_hypr_nord() {
    # 1. Check for internet
    if ! check_internet; then
        exit 1
    fi

    # 2. pacman -Syu
    echo "Synchronizing package databases and updating system..."
    sudo pacman -Syu --noconfirm || { echo "Error: Failed to update system."; exit 1; }

    # 3. Add Chaotic-AUR repo
    echo "Adding Chaotic-AUR repository..."
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || { echo "Error: Failed to receive Chaotic-AUR key."; exit 1; }
    sudo pacman-key --lsign-key 3056513887B78AEB || { echo "Error: Failed to sign Chaotic-AUR key."; exit 1; }

    if ! grep -q "chaotic-aur" /etc/pacman.conf; then
        echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf &> /dev/null
        echo "Server = https://eu.mirror.chaotic.cx/\$repo/\$arch" | sudo tee /etc/pacman.d/chaotic-mirrorlist &> /dev/null
        echo "Chaotic-AUR repository added to pacman.conf and mirrorlist created."
    else
        echo "Chaotic-AUR repository already exists in pacman.conf."
    fi
    sudo pacman -Syy || { echo "Error: Failed to refresh pacman databases after adding Chaotic-AUR."; exit 1; }

    # 4. Install yay
    echo "Installing yay (AUR helper)..."
    if ! command -v yay &> /dev/null; then
        sudo pacman -S --noconfirm yay || { echo "Error: Failed to install yay."; exit 1; }
        echo "yay installed successfully."
    else
        echo "yay is already installed."
    fi

    # 5. Install all the packages from the packages file using yay
    echo "Installing packages from 'packages' file..."
    if [ -f "packages" ]; then
        while IFS= read -r package; do
            if [ -n "$package" ]; then
                echo "Installing $package..."
                yay -S --noconfirm "$package" || { echo "Error: Failed to install $package. Aborting installation."; exit 1; }
            fi
        done < packages
        echo "Package installation complete."
    else
        echo "Error: 'packages' file not found. Skipping package installation."
    fi

    # 6. Copies all the files from Config folder to ~/.config folder
    echo "Copying configuration files to ~/.config..."
    mkdir -p ~/.config || { echo "Error: Failed to create ~/.config directory."; exit 1; }
    cp -r Configs/* ~/.config/ || { echo "Error: Failed to copy config files."; exit 1; }
    echo "Configuration files copied."

    # 7. Copies all the contents of Themes folder to ~/.theme folder and creates one if the .theme folder doesnot exist
    echo "Copying theme files to ~/.themes..."
    mkdir -p ~/.themes || { echo "Error: Failed to create ~/.themes directory."; exit 1; }
    cp -r Theme/* ~/.themes/ || { echo "Error: Failed to copy theme files."; exit 1; }
    echo "Theme files copied."

    # 8. Do the same for the contents of Icons and fonts file repectively to thier appropriate folders which are ~/.icons and ~/.fonts
    echo "Copying icon files to ~/.icons..."
    mkdir -p ~/.icons || { echo "Error: Failed to create ~/.icons directory."; exit 1; }
    cp -r Icons/* ~/.icons/ || { echo "Error: Failed to copy icon files."; exit 1; }
    echo "Icon files copied."

    echo "Copying font files to ~/.fonts..."
    mkdir -p ~/.fonts || { echo "Error: Failed to create ~/.fonts directory."; exit 1; }
    cp -r Fonts/* ~/.fonts/ || { echo "Error: Failed to copy font files."; exit 1; }
    echo "Font files copied."
    echo "Rebuilding font cache..."
    fc-cache -fv || { echo "Error: Failed to rebuild font cache."; }

    # 9. Changes the default shell to zsh if zsh doesnot exist then installs zsh
    echo "Checking and setting default shell to zsh..."
    if ! command -v zsh &> /dev/null; then
        echo "zsh not found. Installing zsh..."
        yay -S --noconfirm zsh || { echo "Error: Failed to install zsh."; exit 1; }
        echo "zsh installed."
    else
        echo "zsh is already installed."
    fi

    if [ "$SHELL" != "$(which zsh)" ]; then
        echo "Changing default shell to zsh..."
        chsh -s "$(which zsh)" || { echo "Error: Failed to change default shell to zsh."; }
        echo "Default shell changed to zsh. Please log out and log back in for changes to take effect."
    else
        echo "Default shell is already zsh."
    fi

    # Copy .zshrc to home directory
    echo "Copying .zshrc to home directory..."
    cp .zshrc ~/.zshrc || { echo "Error: Failed to copy .zshrc."; exit 1; }
    echo ".zshrc copied."

    # Copy Wallpapers folder to ~/Pictures
    echo "Copying Wallpapers to ~/Pictures..."
    mkdir -p ~/Pictures || { echo "Error: Failed to create ~/Pictures directory."; exit 1; }
    cp -r Wallpapers/* ~/Pictures/ || { echo "Error: Failed to copy wallpapers."; exit 1; }
    echo "Wallpapers copied."

    echo "Installation script finished."
}

# Execute the main function
install_hypr_nord
