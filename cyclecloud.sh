
#!/bin/bash

set -e  # Exit on any error

# Define variables
CYCLECLOUD_REPO_URL="https://packages.microsoft.com/yumrepos/cyclecloud"
CYCLECLOUD_CLI_ZIP="/opt/cycle_server/tools/cyclecloud-cli.zip"
PYTHON_VERSION="3.9"
JAVA_PACKAGE="java-1.8.0-openjdk-devel"
CYCLECLOUD_PACKAGE="cyclecloud8"
CYCLECLOUD_REPO_TEMPLATES="add the url here"

# Define variables
UI_GITHUB_URL="https://raw.githubusercontent.com/Azure/az-hop/refs/heads/main/playbooks/roles/cyclecloud/files/configure.py"
UI_SCRIPT_NAME="configure.py"

CYCLECLOUD_UI_CONFIGURATION_SCRIPT_REPO="https://raw.githubusercontent.com/Azure/az-hop/refs/heads/main/playbooks/roles/cyclecloud/files/configure.py"
LOG_FILE="/var/log/cyclecloud_install-$(date +"%Y-%m-%d %H:%M").log"
VERBOSE=false

# Function for logging
log() {
    local message="$1"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $message" | tee -a "$LOG_FILE"
}

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    log "This script must be run as root or with elevated privileges." >&2
    exit 1
fi

# Check for required parameters
if [ "$#" -lt 1 ]; then
    log "Usage: $0 {install|uninstall|update} [-v]" >&2
    exit 1
fi

# Check for verbose flag
if [[ "$2" == "-v" ]]; then
    VERBOSE=true
fi

# Determine action based on the parameter
ACTION="$1"
case "$ACTION" in
    install)
        log "Proceeding with installation..."

        # Install required packages if they are not already installed
        log "Installing required packages"
        for package in wget curl tar jq sudo gcc openssl-devel bzip2-devel libffi-devel make $JAVA_PACKAGE; do
            if ! rpm -q "$package" &> /dev/null; then
                log "Installing $package..."
                yum install -y "$package"
            else
                log "$package is already installed."
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
        if ! rpm -q "python${PYTHON_VERSION}" &> /dev/null; then
            log "Installing Python $PYTHON_VERSION..."
            yum install -y python${PYTHON_VERSION}
        else
            log "Python $PYTHON_VERSION is already installed."
        fi

                # Ensure Python 3.9 is the default python3 version
        log "Setting Python $PYTHON_VERSION as the default python3..."
        alternatives --set python3 /usr/bin/python${PYTHON_VERSION}

        # Enable python to perform tar to absolute paths (CVE 2007-4559)
        export PYTHON_TARFILE_EXTRACTION_FILTER='fully_trusted'

        # Install CycleCloud web application and CLI toolset if not already installed
        if ! rpm -q "$CYCLECLOUD_PACKAGE" &> /dev/null; then
            log "Installing CycleCloud..."
            yum install -y "$CYCLECLOUD_PACKAGE"

            # Start the CycleCloud service if it is not running automatically
            echo "Starting CycleCloud service..."
            systemctl enable cycle_server
            systemctl start cycle_server
        else
            log "CycleCloud is already installed."
        fi

        # CycleCloud CLI installation
        log "Verifying CycleCloud CLI is installed in the system"

        if rpm -q cyclecloud &> /dev/null; then
            log "Cyclecloud CLI is already installed."
        else
            # Ensure the CLI zip file exists
            if [ -f "$CYCLECLOUD_CLI_ZIP" ]; then
                # Install CycleCloud CLI
                log "Installing CycleCloud CLI..."
                log "Unzipping CycleCloud CLI..."
                sudo unzip -o "$CYCLECLOUD_CLI_ZIP" -d /tmp/

                if [ ! -d "/tmp/cyclecloud-cli-installer" ]; then
                  log "The cyclecloud-cli-installer folder could not be found in the /tmp area"
                  exit 1
                fi
                # Navigate to the installation directory
                cd /tmp/cyclecloud-cli-installer || exit

                # Run the installation script
                log "Running the CycleCloud CLI installation script..."
                sudo ./install.sh                
                
                # Define the directory to add
                NEW_DIR="/root/bin"

                # Check if the directory exists
                if [ -d "$NEW_DIR" ]; then
                    # Prepend the directory to PATH
                    sudo export PATH="$NEW_DIR:$PATH"
                    echo "Added $NEW_DIR to PATH."
                else
                    echo "$NEW_DIR does not exist. Please create it or check the path."
                    exit 1
                fi

                # Validate the installation
                if command -v sudo cyclecloud &> /dev/null; then
                    log "CycleCloud CLI installed successfully."
                    sudo cyclecloud --version
                else
                    log "CycleCloud CLI installation failed." >&2
                    exit 1
                fi
            else
                log "CycleCloud CLI zip file not found at $CYCLECLOUD_CLI_ZIP" >&2
                exit 1
            fi
        fi

        # Configure the CycleCloud UI  (scripts by MS)

        # Pull the Python script from GitHub
        log "Downloading CycleUI Python configuration script from GitHub..."
        curl -o "$SCRIPT_NAME" "$GITHUB_URL"  # or use wget: wget -O "$SCRIPT_NAME" "$GITHUB_URL"

        # Check if the download was successful
        if [ $? -eq 0 ]; then
            log "Downloaded $SCRIPT_NAME successfully."
        else
            log "Failed to download $SCRIPT_NAME." >&2
            exit 1
        fi

#        # Execute the Python script
#        echo "Executing $SCRIPT_NAME..."
#        python3 "$SCRIPT_NAME"
#
#        # Check if the script executed successfully
#        if [ $? -eq 0 ]; then
#            echo "Execution of $SCRIPT_NAME completed successfully."
#        else
#            echo "Execution of $SCRIPT_NAME failed." >&2
#            exit 1
#        fi

        ;;

    uninstall)
        log "Proceeding with uninstallation..."

        # Uninstall CycleCloud if installed
        if rpm -q "$CYCLECLOUD_PACKAGE" &> /dev/null; then
            log "Uninstalling CycleCloud..."
            yum remove -y "$CYCLECLOUD_PACKAGE"
            if [ -d "/opt/cycle_server" ]; then
                log "Removing opt/cycle_server directory"
                sudo rm -R /opt/cycle_server
                log "opt/cycle_server directory has been removed."
                log "Removing cyclecloud cli from root/bin"
                sudo rm /root/bin/cyclecloud
                sudo rm -R /root/.cycle
                log "Cyclecloud cli succesfully removed"
            fi
        else
            log "CycleCloud is not installed."
        fi

        # Uninstall Python 3.9 if installed
        if rpm -q "python${PYTHON_VERSION}" &> /dev/null; then
            log "Uninstalling Python $PYTHON_VERSION..."
            yum module reset -y "python${PYTHON_VERSION}"
            yum remove -y "python${PYTHON_VERSION}"
        else
            log "Python $PYTHON_VERSION is not installed."
        fi

        # Revert to the previous default Python version
        log "Reverting to the default Python version..."
        alternatives --set python3 /usr/bin/python3.6

        # Uninstall Java 8 if installed
        if rpm -q "$JAVA_PACKAGE" &> /dev/null; then
            log "Uninstalling Java 8..."
            yum remove -y "$JAVA_PACKAGE"
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

        # Uninstall required packages
        log "Uninstalling required packages"
        for package in wget tar jq gcc openssl-devel bzip2-devel libffi-devel make $JAVA_PACKAGE; do
            if rpm -q "$package" &> /dev/null; then
                log "Uninstalling $package..."
                yum remove -y "$package" --nobest --skip-broken
            else
                log "$package is already uninstalled."
            fi
        done


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
        if [ -f "$CYCLECLOUD_CLI_ZIP" ]; then
            log "Unzipping CycleCloud CLI..."
            sudo unzip -o "$CYCLECLOUD_CLI_ZIP" -d /opt/cycle_server/tools/
            
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
            log "CycleCloud CLI zip file not found at $CYCLECLOUD_CLI_ZIP" >&2
            exit 1
        fi

        ;;

    *)
        log "Invalid option: $ACTION" >&2
        log "Usage: $0 {install|uninstall|update}" >&2
        exit 1
        ;;
esac

# Verbose output
if [ "$VERBOSE" = true ]; then
    log "Verbose mode is ON."
fi

#function createdomainjoinvmfile(){
#if [ ! -f /tmp/domain-join.sh ];
#
#cat <<DOMAINFILEEOF > /tmp/domain-join.sh
##!/bin/sh
##--------------------------------
##---  Must run as the root user
##--------------------------------
#if [ `whoami` != "root" ] ; then
#   echo 'ERROR: The "linuxDomainJoin.sh" MUST run as "root"'
#   exit
#fi
#
##--------------------------------------------
##--- Assigned passed arguments to variables
##---------------------------------------------
#
##-------------------------------------------------------
##--- Add additional yum repos for required packages to
##--- the /etc/yum.repos.d directory.
##-------------------------------------------------------
#if [ ! -f /etc/yum.repos.d/azure-cli.repo ] ; then
#   echo "[azure-cli]"                                                > /etc/yum.repos.d/azure-cli.repo
#   echo "name=Azure CLI"                                            >> /etc/yum.repos.d/azure-cli.repo
#   echo "baseurl=https://packages.microsoft.com/yumrepos/azure-cli" >> /etc/yum.repos.d/azure-cli.repo
#   echo "enabled=1"                                                 >> /etc/yum.repos.d/azure-cli.repo
#   echo "gpgcheck=1"                                                >> /etc/yum.repos.d/azure-cli.repo
#   echo "gpgkey=https://packages.microsoft.com/keys/microsoft.asc"  >> /etc/yum.repos.d/azure-cli.repo
#   chmod 644 /etc/yum.repos.d/azure-cli.repo
#fi
#
##--------------------------------------
##--- Declare packages to be installed
##--------------------------------------
#echo ""
#echo "======================="
#echo "=== Update Packages ==="
#echo "======================="
#BASEDIR=/tmp/PostProvision
#PKGS=("azure-cli" "sssd" "authselect" "adcli" "sysstat" "bind-utils" "realmd"
#      "krb5-workstation" "krb5-libs" "samba-common" "samba-common-tools" "unzip"
#      "samba-winbind-clients" "oddjob" "oddjob-mkhomedir" "samba-winbind-modules"
#      "pam_krb5" "cifs-utils")
#
##---------------------------------------------------------------
##--- Install Package only if they have not yet been installed
##---------------------------------------------------------------
#for PKG in ${PKGS[@]} ; do
#   if [ `yum list installed 2> /dev/null | grep -c "$PKG\."` == 0 ] ; then
#      echo "... INSTALL ............. $PKG"
#      yum install $PKG -y > /dev/null
#   else
#      echo "... ALREADY installed ... $PKG"
#   fi
#done
#
#
#az login --identity --username bf390057-b287-4b79-9ea0-e8b667fe35bd
#az account set -s a5d2b45b-f9b1-4ad0-aee5-66160e64052c
#
#ADPWsecret=$(az keyvault secret show --name vm-admin-credential --vault-name KV-SAT-Infra-01 --query value -o tsv)
#region_prefix=east
#HPA_GRP="RG-BH_HPC_Cloud_Azure-NP-SUB-000005-EastU_XAIQ1BCXRW_LHdev"
#
##systemctl start oddjobd > /dev/null
#
##---------------------------------------------------
##--- Create the sssd directory if it does not exist
##---------------------------------------------------
#if [ ! -d /etc/sssd ] ; then
#   mkdir /etc/sssd
#   chmod /etc/sssd
#fi
#
#cat <<EOF > /etc/krb5.conf
## Configuration snippets may be placed in this directory as well
#includedir /etc/krb5.conf.d/
#
#[logging]
# default = FILE:/var/log/krb5libs.log
# kdc = FILE:/var/log/krb5kdc.log
# admin_server = FILE:/var/log/kadmind.log
#
#[libdefaults]
#default_realm = ent.bhicorp.com
#dns_lookup_realm = false
#dns_lookup_kdc = true
#ticket_lifetime = 24h
#renew_lifetime = 7d
#forwardable = true
#rdns = false
#pkinit_anchors = /etc/pki/tls/certs/ca-bundle.crt
#default_ccache_name = KEYRING:persistent:%{uid}
#udp_preference_limit  = 1
#
#[realms]
#ent.bhicorp.com = {
#	#kdc = 
#	kdc = ent.bhicorp.com
#	#admin_server = 
#	admin_server = ent.bhicorp.com
#	master_kdc = ADSERVERVALUE
#	default_domain = ent.bhicorp.com
#}
#
#[domain_realm]
#.ent.bhicorp.com = ENT.BHICORP.COM
# ent.bhicorp.com = ENT.BHICORP.COM
#
#[appdefaults]
#pam = {
#	debug = false
#	tickert_lifetime = 36000
#	renew_lifetime = 36000
#	forwardable = true
#	krb4_convert = false
#}
#EOF
#
#cat <<EOF > /etc/samba/smb.conf
#[global]
#   workgroup = ent
#   #password server = 
#   password server = *
#   interfaces = eth0
#   realm = ent.bhicorp.com
#   security = ads
#   encrypt passwords = yes
#   client ntlmv2 auth = yes
#   client ldap sasl wrapping = sign
#   kerberos method = secrets and keytab
#   ldap ssl = off
#   log level = 5
#   max log size = 300
#   log file = /var/log/samba/%m.log
#EOF
#
#cat <<EOF > /etc/sssd/sssd.conf
#[sssd]
#services = nss, pam, ssh
#config_file_version = 2
#domains = ent.bhicorp.com
#
#[domain/ent.bhicorp.com]
## Uncomment and configure below , if service discovery is not working 
#ad_server = ADSERVERVALUE
#ad_domain = ent.bhicorp.com
#krb5_realm = ent.bhicorp.com
#krb5_validate = False
#realmd_tags = manages-system joined-with-adcli
#id_provider = ad
#cache_credentials = True
#krb5_store_password_if_offline = True
#ldap_id_mapping = True
#use_fully_qualified_names = False
#auth_provider = ad
#chpass_provider = ad
#access_provider = ad
#override_homedir = /netapp/home/%u
#debug_level = 3
#ad_gpo_access_control = disabled
#ad_gpo_ignore_unreadable = True
#dyndns_update = True
#dyndns_refresh_interval = 43200
#dyndns_update_ptr = True
#dyndns_ttl = 3600
#
#[nss]
#override_shell=/bin/bash
#
#[pam]
#pam_verbosity = 3
#EOF
#
#if [[ "$region_prefix" == "east" ]] ; then
#   ad_server_value="AZUCDC02.ent.bhicorp.com, AZUCDC01.ent.bhicorp.com"
#elif [[ "$region_prefix" == "west" ]] || [[ "$region_prefix" == "qata" ]] ; then
#   ad_server_value="AZECDC02.ent.bhicorp.com, AZECDC01.ent.bhicorp.com"
#else
#   echo 'ERROR: Location "east" or "west" or "qata" not passed'
#   exit
#fi
#
#sed -i "s/ADSERVERVALUE/$ad_server_value/g" /etc/sssd/sssd.conf
#sed -i "s/ADSERVERVALUE/$ad_server_value/g" /etc/krb5.conf
##-----------------------------
##--- Adjust files attributes
##-----------------------------
#chmod 644 /etc/krb5.conf
#chmod 600 /etc/sssd/sssd.conf
#
#cp -prf /etc/sssd/sssd.conf /etc/sssd/sssd.conf_backup
#
#sudo chmod 600 /etc/sssd/sssd.conf
#
#realm leave
#
#echo -e "PEERDNS=yes\nDOMAIN=ent.bhicorp.com" >> /etc/sysconfig/network-scripts/ifcfg-eth0
##-----------------------------------
##--- Join the Baker Hughes Domain
##-----------------------------------
#echo ""
#echo "===================================="
#echo "=== Join the Baker Hughes Domain ==="
#echo "===================================="
#echo "... joining $(hostname) to the \"ent.bhicorp.com\" domain"
#completeOUPath='OU=Managed Servers - Azure,DC=ent,DC=bhicorp,DC=com'
#subOU="NotApplicable"
#if [ "$subOU" != "NotApplicable" ]; then
# 	completeOUPath="${subOU},${completeOUPath}"
#fi
#
#echo "$ADPWsecret" | adcli join --stdin-password --domain-ou="${completeOUPath}" -U svc-mynavagent ent.bhicorp.com
#if [ $? -eq 0 ]
#then 
# echo "adjoin complete"
#else
#  echo "adjoin not complete"
#fi
#
#osRelease=$(source '/etc/os-release'; echo "${ID}${VERSION_ID%%.*}")
#if [[ ${osRelease} == "rhel9" ]] || [[ ${osRelease} == "rhel8" ]] || [[ ${osRelease} == "almalinux9" ]] || [[ ${osRelease} == "oel9" ]]; then
#    echo "Skipping authselect for RHEL 9"
#    # Create and configure custom 'bhc-sssd' authselect profile
#    echo "Configuring custom 'bhc-sssd' authselect profile..."
#    dnf -y install oddjob oddjob-mkhomedir
#    authselect create-profile bhc-sssd --base-on=sssd
#    authselect select custom/bhc-sssd --force
#    authselect enable-feature with-mkhomedir
#else
#    authselect --enablesssd --enablesssdauth --enablelocauthorize --enablemkhomedir --update
#fi
#
#
#cp -prf /etc/sssd/sssd.conf_backup /etc/sssd/sssd.conf
#
##------------------------
##--- Restart AD daemons
##------------------------
#systemctl start oddjobd && systemctl enable oddjobd
#sleep 5
#if [ `systemctl status oddjobd | grep -c active` == 1 ] ; then
#   echo "... oddjobd        start SUCESSFUL"
#else
#   echo "... oddjobd        start FAILED"
#fi
#
#systemctl start sssd
#if [ `systemctl status sssd | grep -c active` == 1 ] ; then
#   echo "... sssd           start SUCESSFUL"
#else
#   echo "... sssd           start FAILED"
#fi
#
#systemctl restart systemd-logind
#if [ `systemctl status systemd-logind | grep -c active` == 1 ] ; then
#   echo "... systemd-logind start SUCESSFUL"
#else
#   echo "... systemd-logind start FAILED"
#fi
#
#echo "... enable sssd"
#systemctl enable sssd
#
#systemctl restart sshd
#if [ `systemctl status sshd | grep -c active` == 1 ] ; then
#   echo "... sshd           start SUCESSFUL"
#else
#   echo "... sshd           start FAILED"
#fi
#
##------------------------------------------------------------------------
##--- Adding groups to allow ssh and sudoer access to the VM
##------------------------------------------------------------------------
#
##ADDITIONALGRP="$3"
##IFS=',' read -ra HPA_GRP <<< "${ADDITIONALGRP//[\"\'\[\]]/}"
#GRPS=("BHCAzure_HPA_ALL" "BHCAzure_LinuxAdmin_HPA" "BHCAzure_SAT_Linux_HPA" "${HPA_GRP}")
#
#for GRP in ${GRPS[@]} ; do
#   if [ `grep -c "$GRP" /etc/security/access.conf` == 0 ] ; then
#      echo "+:@$GRP@ent.bhicorp.com:ALL" >> /etc/security/access.conf
#   else
#      sed -i 's/^+:@$GRP.*/+:@$GRP@ent.bhicorp.com:ALL/' /etc/security/access.conf
#   fi
#done
#
#for GRP in ${GRPS[@]} ; do
#   if [ -f /etc/login.group.allowed ] ; then
#      if [ `grep -c "$GRP" /etc/login.group.allowed` == 0 ] ; then
#         echo "$GRP" >> /etc/login.group.allowed
#      fi
#   else
#     echo "$GRP" >> /etc/login.group.allowed
#   fi
#   chmod 644 /etc/login.group.allowed
#done
#
#for GRP in ${GRPS[@]} ; do
#   echo "... update /etc/sudoers"
#   if [ `grep -c "$GRP" /etc/sudoers` == 0 ] ; then
#      echo "%ent.bhicorp.com\\\\"$GRP" ALL=(ALL) ALL" >> /etc/sudoers
#   else
#      sed -i 's/.*$GRP.*/%ent.bhicorp.com\\\\$GRP ALL=(ALL) ALL/' /etc/sudoers
#   fi  
#done
#
#systemctl restart sssd
#
##Enabling Qualys Agent
##qualysActivationId=$5
##qualysCustomerId=$6
#
##Start Qualys Agent Service
##sudo rpm -ivh QualysCloudAgent.rpm
##sudo /usr/local/qualys/cloud-agent/bin/qualys-cloud-agent.sh ActivationId=$qualysActivationId CustomerId=$qualysCustomerId
#
##Run Latest Updates
#sed -i "s/repo_gpgcheck=1/repo_gpgcheck=0/" /etc/dnf/dnf.conf
##sudo dnf upgrade -y
#DOMAINFILEEOF
#fi
#
#}
#