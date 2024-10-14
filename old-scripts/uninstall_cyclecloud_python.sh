#!/bin/bash

set -e  # Exit on any error

# Define variables
CYCLECLOUD_REPO_PATH="/etc/yum.repos.d/cyclecloud.repo"
PYTHON_VERSION="3.9"

# Uninstall CycleCloud
echo "Uninstalling CycleCloud..."
yum remove -y cyclecloud

# Uninstall Python 3.9
echo "Uninstalling Python ${PYTHON_VERSION}..."
yum module reset -y python${PYTHON_VERSION}
yum remove -y python${PYTHON_VERSION}

# Remove CycleCloud repository
if [ -f "${CYCLECLOUD_REPO_PATH}" ]; then
    echo "Removing CycleCloud repository..."
    rm -f "${CYCLECLOUD_REPO_PATH}"
else
    echo "CycleCloud repository file not found. Skipping removal."
fi

# Clean up
echo "Cleaning up..."
yum autoremove -y
yum clean all

echo "Uninstallation of CycleCloud and Python ${PYTHON_VERSION} completed successfully."
