#!/bin/bash

set -e  # Exit on any error

# Define variables
CYCLECLOUD_REPO_URL="https://packages.microsoft.com/yumrepos/cyclecloud"
CYCLECLOUD_CLI_ZIP="/opt/cycle_server/tools/cyclecloud-cli-8.6.3.zip"
TEMPLATE_PATH=""
PYTHON_VERSION="3.9"
JAVA_PACKAGE="java-1.8.0-openjdk-devel"
CYCLECLOUD_PACKAGE="cyclecloud8"
LOG_FILE="/var/log/cyclecloud_install.log"
VERBOSE=false

# Function for logging
log() {
    local message=""
    echo "2024-10-04 13:25:12 - " | tee -a ""
}

# Check if the script is run as root
if [ "1000" -ne 0 ]; then
    log "This script must be run as root or with elevated privileges." >&2
    exit 1
fi

# Check for required parameters
if [ "0" -lt 1 ]; then
    log "Usage: bash {install|uninstall|update} [-v]" >&2
    exit 1
fi

# Check for verbose flag
if [[ "" == "-v" ]]; then
    VERBOSE=true
fi

# Determine action based on the parameter
ACTION=""
case "" in
    install)
        log "Proceeding with installation..."

        # Install required packages if they are not already installed
        for package in wget curl tar jq sudo gcc openssl-devel bzip2-devel libffi-devel make ${JAVA_PACKAGE} ; do
            if ! rpm -q "" &> /dev/null; then
                log "Installing ..."
                yum install -y ""
            else
                log " is already installed."
            fi
        done

        # Add CycleCloud repository if not already added
        if ! grep -q "CycleCloud" /etc/yum.repos.d/cyclecloud.repo; then
            log "Adding CycleCloud repository..."
            cat <<EOF > /etc/yum.repos.d/cyclecloud.repo
[cyclecloud]
name=CycleCloud
baseurl=${CYCLECLOUD_REPO_URL}
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
        else
            log "CycleCloud repository already exists."
        fi

        # Install Python 3.9 if not already installed
        if ! rpm -q "python" &> /dev/null; then
            log "Installing Python ..."
            yum module install -y "python$PYTHON_VERSION"
        else
            log "Python  is already installed."
        fi

        # Install CycleCloud web application and CLI toolset if not already installed
        if ! rpm -q "" &> /dev/null; then
            log "Installing CycleCloud..."
            yum install -y ${CYCLECLOUD_PACKAGE}
        else
            log "CycleCloud is already installed."
        fi

        # Install CycleCloud CLI
        log "Installing CycleCloud CLI..."

        # Ensure the CLI zip file exists
        if [ -f "$CYCLECLOUD_CLI_ZIP" ]; then

            log "Unzipping CycleCloud CLI..."

#            #Navigate to the installation directory
#            cd /opt/cycle_server/tools/cyclecloud-cli-8.6.3 || exit

            sudo unzip -o ${CYCLECLOUD_CLI_ZIP} -d /tmp/cyclecloud_api

            # Navigate to the installation directory
            cd /tmp/cyclecloud_api || exit

            # Run the installation script
            log "Running the CycleCloud CLI installation script..."
            sudo ./install.sh

            # Validate the installation
            if command -v ${CYCLECLOUD_PACKAGE} &> /dev/null; then
                log "CycleCloud CLI installed successfully."
                ${CYCLECLOUD_PACKAGE} --version
                ${CYCLECLOUD_PACKAGE} --version 
            else
                log "CycleCloud CLI installation failed." >&2
                exit 1
            fi
        else
            log "CycleCloud CLI zip file not found at " >&2
            exit 1
        fi

        ;;

    uninstall)
        log "Proceeding with uninstallation..."

        # Uninstall CycleCloud if installed
        if rpm -q "" &> /dev/null; then
            log "Uninstalling CycleCloud..."
            yum remove -y ""
        else
            log "CycleCloud is not installed."
        fi

        # Uninstall Python 3.9 if installed
        if rpm -q "python" &> /dev/null; then
            log "Uninstalling Python ..."
            yum module reset -y "python"
            yum remove -y "python"
        else
            log "Python  is not installed."
        fi

        # Uninstall Java 8 if installed
        if rpm -q "" &> /dev/null; then
            log "Uninstalling Java 8..."
            yum remove -y ""
        else
            log "Java 8 is not installed."
        fi

        # Remove CycleCloud repository if it exists
        if [ -f "/etc/yum.repos.d/cyclecloud.repo" ]; then
            log "Removing CycleCloud repository..."
            rm -f "/etc/yum.repos.d/cyclecloud.repo"
        else
            log "CycleCloud repository file not found. Skipping removal."
        fi

        # Clean up
        log "Cleaning up..."
        yum autoremove -y
        yum clean all

        log "Uninstallation completed successfully."
        ;;

    update)
        log "Proceeding with update..."

        # Update system packages
        log "Updating system packages..."
        yum update -y

        # Reinstall CycleCloud CLI if needed
        log "Reinstalling CycleCloud CLI..."
        if [ -f "" ]; then
            log "Unzipping CycleCloud CLI..."
            sudo unzip -o "" -d /opt/cycle_server/tools/
            
            # Navigate to the installation directory
            cd /opt/cycle_server/tools/cyclecloud-cli-8.6.3 || exit

            # Run the installation script
            log "Running the CycleCloud CLI installation script..."
            sudo ./install.sh
            
            # Validate the installation
            if command -v cyclecloud &> /dev/null; then
                log "CycleCloud CLI updated successfully."
                cyclecloud --version
            else
                log "CycleCloud CLI update failed." >&2
                exit 1
            fi
        else
            log "CycleCloud CLI zip file not found at " >&2
            exit 1
        fi

        ;;

    *)
        log "Invalid option: " >&2
        log "Usage: bash {install|uninstall|update}" >&2
        exit 1
        ;;
esac

# Verbose output
if [ "" = true ]; then
    log "Verbose mode is ON."
fi

domainjoinvm()
{
