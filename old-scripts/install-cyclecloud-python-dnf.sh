#!/bin/bash

set -e  # Exit on any error

# Define variables
CYCLECLOUD_REPO_URL="https://cyclecloud.azureedge.net/repo/centos8/"
PYTHON_VERSION="3.9"

# Update system
echo "Updating system..."
dnf update -y

# Install required packages
echo "Installing required packages..."
dnf install -y \
    wget \
    curl \
    tar \
    jq \
    sudo \
    gcc \
    openssl-devel \
    bzip2-devel \
    libffi-devel \
    make

# Add CycleCloud repository
echo "Adding CycleCloud repository..."
cat <<EOF > /etc/yum.repos.d/cyclecloud.repo
[cyclecloud]
name=CycleCloud
baseurl=${CYCLECLOUD_REPO_URL}
enabled=1
gpgcheck=1
gpgkey=https://cyclecloud.azureedge.net/repo/centos8/RPM-GPG-KEY-cyclecloud
EOF

# Install Python 3.9
echo "Installing Python ${PYTHON_VERSION}..."
dnf module install -y python${PYTHON_VERSION}

# Install CycleCloud web application and CLI toolset
echo "Installing CycleCloud..."
dnf install -y cyclecloud

# Verify installations
echo "Verifying Python installation..."
python3.9 --version

echo "Verifying CycleCloud installation..."
cyclecloud --version

# Additional configuration (if required)
# For example, start the CycleCloud service if it is not running automatically
echo "Starting CycleCloud service..."
systemctl enable cyclecloud
systemctl start cyclecloud

echo "Python ${PYTHON_VERSION} and CycleCloud installation and configuration completed successfully."
