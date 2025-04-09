#!/bin/bash

# 加载系统函数库(Only for RHEL Linux) - Optional, uncomment if needed
# [ -f /etc/init.d/functions ] && source /etc/init.d/functions

# 获取脚本工作目录绝对路径
Server_Dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# Define directories
Conf_Dir="$Server_Dir/conf"
Log_Dir="$Server_Dir/logs"
Bin_Dir="$Server_Dir/bin" # Directory for the clash binary
Dashboard_Dir="${Server_Dir}/dashboard/public" # Assuming dashboard files are here

# --- Clash Core Download Configuration ---
Clash_Version="1.18.0"
Clash_Release_Tag="1.18" # Tag used in the download URL
Base_Download_URL="https://github.com/Kuingsmile/clash-core/releases/download/${Clash_Release_Tag}"

# --- Configuration File Path ---
Expected_Config_File="$Conf_Dir/config.yaml"

# --- Helper Functions (Copied from original) ---
success() {
  echo -en "\\033[60G[\\033[1;32m  OK   \\033[0;39m]\r"
  return 0
}

failure() {
  local rc=$?
  echo -en "\\033[60G[\\033[1;31mFAILED\\033[0;39m]\r"
  [ -x /bin/plymouth ] && /bin/plymouth --details # Optional: for systems with plymouth
  return $rc
}

action() {
  local STRING rc

  STRING=$1
  echo -n "$STRING "
  shift
  "$@" && success $"$STRING" || failure $"$STRING"
  rc=$?
  echo
  return $rc
}

# 判断命令是否正常执行 函数
if_success() {
  local ReturnStatus=$3
  if [ $ReturnStatus -eq 0 ]; then
        action "$1" /bin/true
  else
        action "$2" /bin/false
        exit 1
  fi
}

# --- Script Logic ---

echo -e "\nStarting Clash Setup..."

# 1. Create necessary directories if they don't exist
mkdir -p "$Conf_Dir" "$Log_Dir" "$Bin_Dir" # Ensure Bin_Dir is created
if_success "Created necessary directories" "Failed to create directories" $?

# 2. Check if the user-provided config.yaml exists
echo -e "\nChecking for configuration file..."
Text1="Found configuration file: $Expected_Config_File"
Text2="ERROR: Configuration file not found at $Expected_Config_File. Please place your config.yaml there."
if [ -f "$Expected_Config_File" ]; then
    action "$Text1" /bin/true
else
    action "$Text2" /bin/false
    exit 1
fi

# 3. (Optional) Ensure Dashboard path is correctly set in the config file
echo -e "\nConfiguring Clash Dashboard path..."
if [ -d "$Dashboard_Dir" ]; then
    sed -ri "s@^#? *external-ui:.*@external-ui: ${Dashboard_Dir}@" "$Expected_Config_File"
    action "Set Dashboard directory in config" /bin/true
else
    echo "Dashboard directory $Dashboard_Dir not found, skipping external-ui configuration."
fi

# 4. Get RESTful API Secret from the config file
echo -e "\nReading API Secret..."
# Use sed for better compatibility than grep -P lookbehind
Secret=$(sed -n -E "s/^secret: *['\"]?([^'\"]*)['\"]?/\1/p" "$Expected_Config_File" | head -n 1)
if [ -n "$Secret" ]; then
    action "Retrieved API Secret" /bin/true
else
    action "API Secret not found or empty in config (may be intentional)" /bin/true
    Secret="Not Set"
fi

# 5. Detect CPU Architecture
echo -e "\nDetecting CPU Architecture..."
CpuArch=""
if /bin/arch &>/dev/null; then
    CpuArch=$(/bin/arch)
elif /usr/bin/arch &>/dev/null; then
    CpuArch=$(/usr/bin/arch)
elif /bin/uname -m &>/dev/null; then
    CpuArch=$(/bin/uname -m)
fi

if [ -z "$CpuArch" ]; then
    action "Failed to obtain CPU architecture!" /bin/false
    exit 1
else
    action "Detected CPU Architecture: $CpuArch" /bin/true
fi

# --- Download and Prepare Clash Core Binary ---
echo -e "\nPreparing Clash Core Binary (v${Clash_Version})..."

Arch_Suffix=""
Target_Binary_Name="" # Final name like clash-linux-amd64
if [[ $CpuArch =~ "x86_64" ]]; then
    Arch_Suffix="amd64"
    Target_Binary_Name="clash-linux-amd64"
elif [[ $CpuArch =~ "aarch64" ]]; then
    Arch_Suffix="arm64"
    Target_Binary_Name="clash-linux-arm64"
elif [[ $CpuArch =~ "armv7" ]]; then # Explicitly check armv7
    Arch_Suffix="armv7"
    Target_Binary_Name="clash-linux-armv7"
else
    action "Unsupported CPU architecture for download: $CpuArch" /bin/false
    exit 1
fi

Downloaded_Gz_File="clash-linux-${Arch_Suffix}-v${Clash_Version}.gz"
Extracted_File="clash-linux-${Arch_Suffix}-v${Clash_Version}" # Name after extraction
Download_URL="${Base_Download_URL}/${Downloaded_Gz_File}"
Final_Binary_Path="${Bin_Dir}/${Target_Binary_Name}" # The path script will use

# Check if the correct version already exists and is executable
# If you want to force download every time, remove this check block
if [ -f "$Final_Binary_Path" ] && [ -x "$Final_Binary_Path" ]; then
    # Optional: Add a version check here if the binary supports a --version flag
    echo "Executable Clash binary $Final_Binary_Path already exists."
    action "Using existing binary" /bin/true
else
    echo "Clash binary not found or not executable. Downloading..."
    # Remove potentially outdated/incomplete files before download
    rm -f "${Bin_Dir}/${Downloaded_Gz_File}" "${Bin_Dir}/${Extracted_File}" "${Final_Binary_Path}"

    # Download
    action "Downloading $Downloaded_Gz_File from $Base_Download_URL" \
        wget --no-check-certificate -q -O "${Bin_Dir}/${Downloaded_Gz_File}" "$Download_URL"
    if_success "Download successful" "Download failed" $?

    # Extract
    action "Extracting ${Downloaded_Gz_File}" \
        gunzip -f "${Bin_Dir}/${Downloaded_Gz_File}"
    # Verify extraction result
    if [ -f "${Bin_Dir}/${Extracted_File}" ]; then
        action "Extraction successful" /bin/true
    else
        action "Extraction failed (Extracted file not found)" /bin/false
        ls -l "$Bin_Dir" # List directory contents for debugging
        exit 1
    fi

    # Rename
    action "Renaming ${Extracted_File} to ${Target_Binary_Name}" \
        mv "${Bin_Dir}/${Extracted_File}" "${Final_Binary_Path}"
    if_success "Rename successful" "Rename failed" $?

    # Set Permissions
    action "Setting execute permission for ${Target_Binary_Name}" \
        chmod +x "${Final_Binary_Path}"
    if_success "Permissions set" "Failed to set permissions" $?

    echo "Clash binary is ready at ${Final_Binary_Path}"
fi
# --- End Download Section ---


# 6. Start Clash Service
echo -e '\nStarting Clash service...'
Text5="Clash service started successfully!"
Text6="Failed to start Clash service!"
Log_File="$Log_Dir/clash.log"

# Check if the final binary exists and is executable before trying to run it
if [ ! -f "$Final_Binary_Path" ]; then
    action "Clash binary not found at $Final_Binary_Path after preparation!" /bin/false
    exit 1
fi
if [ ! -x "$Final_Binary_Path" ]; then
    action "Clash binary $Final_Binary_Path is not executable after preparation!" /bin/false
    # Attempt to fix permissions again just in case
    chmod +x "$Final_Binary_Path"
    if [ ! -x "$Final_Binary_Path" ]; then
        action "Failed to make Clash binary executable" /bin/false
        exit 1
    fi
    action "Corrected execute permission" /bin/true
fi

# Start Clash in the background using the prepared binary path
nohup "$Final_Binary_Path" -d "$Conf_Dir" > "$Log_File" 2>&1 &
# Give it a moment to start or fail
sleep 2

# Check if the process is running (using pgrep)
# Make sure pgrep pattern matches the command accurately
if pgrep -f "$Final_Binary_Path -d $Conf_Dir" > /dev/null; then
    ReturnStatus=0 # Success
else
    ReturnStatus=1 # Failure
fi

if_success "$Text5" "$Text6 (Check $Log_File for details)" $ReturnStatus


# 7. Output Dashboard access address and Secret (Improved IP detection)
ExternalController=$(grep '^external-controller:' "$Expected_Config_File" | sed 's/external-controller: *//')
Port=$(echo "$ExternalController" | grep -Po '(?<=:)\d+')
BindAddress=$(grep '^bind-address:' "$Expected_Config_File" | sed 's/bind-address: *//' | tr -d "'\"") # Get bind address
HttpPort=$(grep '^port:' "$Expected_Config_File" | sed 's/port: *//') # Standard HTTP port
MixedPort=$(grep '^mixed-port:' "$Expected_Config_File" | sed 's/mixed-port: *//') # Mixed port

# Determine the access IP
AccessIP="<Your-Server-IP>" # Default placeholder
if [ "$BindAddress" == "*" ] || [ "$BindAddress" == "0.0.0.0" ]; then
    # Try to get the primary IP address if possible (requires `ip` command)
    PrimaryIP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+' 2>/dev/null)
    if [ -n "$PrimaryIP" ]; then
        AccessIP="$PrimaryIP"
    else
        # Fallback if `ip` command fails or isn't available
         AccessIP=$(hostname -I | awk '{print $1}' 2>/dev/null) || AccessIP="<Your-Server-IP>"
    fi
else
    AccessIP="$BindAddress" # If bound to a specific IP
fi


echo ''
echo -e "Clash Dashboard Access: http://${AccessIP}:${Port}/ui"
echo -e "API Secret            : ${Secret}"
[ -n "$HttpPort" ] && echo -e "HTTP Proxy Port       : ${HttpPort}"
[ -n "$MixedPort" ] && echo -e "Mixed Proxy Port      : ${MixedPort} (HTTP/SOCKS)"
echo -e "Log File              : ${Log_File}"
echo ''


# 8. Add environment variable helper functions (requires root/sudo)
echo -e "Setting up proxy environment helper functions..."
ProxyPort="${MixedPort:-7890}" # Use mixed-port if set, otherwise default from original script logic
cat > /tmp/clash.sh.tmp <<EOF
# Added by Clash start script

# Set system proxy environment variables
function proxy_on() {
    export http_proxy="http://127.0.0.1:${ProxyPort}"
    export https_proxy="http://127.0.0.1:${ProxyPort}"
    export no_proxy="127.0.0.1,localhost"
    # Add any other hosts/IPs that should bypass the proxy here, comma-separated
    # export no_proxy="127.0.0.1,localhost,192.168.0.0/16,*.internal.domain"
    echo -e "\\033[32m[√] Proxy environment variables set (http_proxy, https_proxy, no_proxy). Apply to new shells or source this file.\\033[0m"
}

# Unset system proxy environment variables
function proxy_off(){
    unset http_proxy
    unset https_proxy
    unset no_proxy
    echo -e "\\033[31m[×] Proxy environment variables unset.\\033[0m"
}
EOF

# Attempt to move the file using sudo if not root, otherwise move directly
if [[ $EUID -ne 0 ]]; then
  echo "Attempting to install helper functions using sudo..."
  if command -v sudo > /dev/null; then
    sudo mv /tmp/clash.sh.tmp /etc/profile.d/clash.sh && \
    sudo chmod 644 /etc/profile.d/clash.sh
    InstallStatus=$?
  else
    echo "sudo command not found. Cannot install helper functions to /etc/profile.d/"
    InstallStatus=1
  fi
else
  mv /tmp/clash.sh.tmp /etc/profile.d/clash.sh && \
  chmod 644 /etc/profile.d/clash.sh
  InstallStatus=$?
fi

if [ $InstallStatus -eq 0 ]; then
    action "Proxy helper functions installed to /etc/profile.d/clash.sh" /bin/true
    echo -e "\nProxy Helper Commands (run in a new shell or after sourcing):"
    echo -e "  \033[32msource /etc/profile.d/clash.sh\033[0m (Load functions in current shell)"
    echo -e "  \033[32mproxy_on\033[0m                    (Set proxy environment variables)"
    echo -e "  \033[31mproxy_off\033[0m                   (Unset proxy environment variables)"
else
    action "Failed to install proxy helper functions to /etc/profile.d/" /bin/false
    echo -e "\nYou can manually use the commands defined in /tmp/clash.sh.tmp"
    echo -e "Or manually set proxies:"
    echo -e "  export http_proxy=http://127.0.0.1:${ProxyPort}"
    echo -e "  export https_proxy=http://127.0.0.1:${ProxyPort}"
fi
echo ""

exit 0