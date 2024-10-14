#!/bin/bash

set -e  # Exit on any error

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root or with elevated privileges." >&2
        exit 1
        fi

# Check for required parameters
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 {install|uninstall}" >&2
        exit 1
        fi

# Define variables
CYCLECLOUD_REPO_URL="https://packages.microsoft.com/yumrepos/cyclecloud"
PYTHON_VERSION="39"
JAVA_PACKAGE="java-1.8.0-openjdk-devel"
CYCLECLOUD_REPO_TEMPLATES="add the url here"

# Update system
echo "Updating system..."
yum update -y

# Install required packages
echo "Installing required packages..."
yum install -y \
    wget \
    curl \
    tar \
    jq \
    sudo \
    gcc \
    openssl-devel \
    bzip2-devel \
    libffi-devel \
    make \
    java-1.8.0-openjdk-devel  # Install Java 8

# Add CycleCloud repository
echo "Adding CycleCloud repository..."
cat <<EOF > /etc/yum.repos.d/cyclecloud.repo
[cyclecloud]
name=CycleCloud
baseurl=${CYCLECLOUD_REPO_URL}
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# Install Python 3.9
echo "Installing Python ${PYTHON_VERSION}..."
yum module install -y python${PYTHON_VERSION}

# Install CycleCloud web application and CLI toolset
echo "Installing CycleCloud..."
yum install -y cyclecloud8

# Verify installations
echo "Verifying Python installation..."
python3.9 --version

# Verify installations
echo "Verifying Java installation..."
java -version

# Validate CycleCloud installation
echo "Validating CycleCloud installation..."

# Check if the CycleCloud package is installed
if rpm -q cyclecloud; then
  echo "CycleCloud package is installed."
else
  echo "CycleCloud package is not installed."
fi

# Attempt to locate the CycleCloud executable
CYCLECLOUD_PATH=$(which cyclecloud8 2>/dev/null)

if [ -n "$CYCLECLOUD_PATH" ]; then
  echo "CycleCloud executable found at: $CYCLECLOUD_PATH"
  # Optionally check the version if possible
  $CYCLECLOUD_PATH --version || echo "Version check failed for CycleCloud."
else
  echo "CycleCloud executable not found in PATH."
fi

# Additional configuration (if required)
# For example, start the CycleCloud service if it is not running automatically
echo "Starting CycleCloud service..."
systemctl enable cyclecloud8
systemctl start cyclecloud8


# Add the start of the cluster here, verify that they exist and are  

# MVP on  exception management (V2.0)
echo "Java ${JAVA_VERSION}, Python ${PYTHON_VERSION}, and CycleCloud installation and configuration completed successfully."

echo "\n All systems go!"
