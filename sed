#!/bin/bash

# Define the configuration file path
CONFIG_FILE="/opt/cycle_server/config/cycle_server.properties"

# Update the SSL port in the configuration file
echo "Updating SSL port to 443..."
sed -i 's/webServerSslPort=8443/webServerSslPort=443/' "$CONFIG_FILE"

# Enable HTTPS in the configuration file
echo "Enabling HTTPS..."
sed -i 's/webServerEnableHttps=false/webServerEnableHttps=true/' "$CONFIG_FILE"

# Restart the cycle_server service to apply changes
echo "Restarting cycle_server service..."
sudo systemctl restart cycle_server

# Verify if the service restarted successfully
if systemctl is-active --quiet cycle_server; then
   echo "cycle_server service restarted successfully."
else
   echo "Failed to restart cycle_server service." >&2
   exit 1
fi
