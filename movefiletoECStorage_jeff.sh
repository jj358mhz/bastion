#!/usr/bin/env bash
# Bastion script to easily pull files (logs, captures, etc., off slicer servers)

CDN_USERNAME="jjohnston@edg.io@rsync.vny.EEA8.labcdn.com:"
CDN_DOWNLOAD_URL="http://cdn.telcomjj.com"

# Define color codes for output
COL_NC="\033[0m"      # No Color
COL_RED="\033[1;91m"  # Red
COL_GREEN="\033[1;32m"  # Green
COL_YELLOW="\033[1;33m"  # Yellow
COL_PURPLE="\033[1;35m"  # Purple
COL_CYAN="\033[0;36m"  # Cyan

ALERT="[⚠️ ]"
TICK="[${COL_GREEN}✓${COL_NC}]"
CROSS="[${COL_RED}✗${COL_NC}]"
INFO="[$(tput setaf 3)i$(tput sgr0)]"
QUESTION="[${COL_PURPLE}?${COL_NC}]"


# Function to copy the file from slicer to Bastion server
slicer_to_bastion() {
  echo -e "${INFO} ${COL_CYAN}Copying file from slicer to Bastion server...${COL_NC}"
  /usr/bin/scp -4 -l "$Speed" -i "$UKey" "root@$FullServerName:$PathandFile" "/home/ecdc/$User/$changedActualFile"
  local scp_status=$?
  if [ $scp_status -eq 0 ]; then
    echo -e "${TICK} File copy from slicer to Bastion server complete..."
  else
    echo -e "${CROSS} ${COL_RED}Failed to copy the file from slicer to Bastion server.${COL_NC}"
    exit 1
  fi
}


# Function to copy the file from Bastion server to storage
bastion_to_storage() {
  echo -e "${INFO} ${COL_CYAN}Copying file from Bastion server to storage...${COL_NC}"
  /usr/bin/scp -4 -i "$UKey" "/home/ecdc/$User/$changedActualFile" "$CDN_USERNAME$RemoteServerPath"
  local scp_status=$?
  if [ $scp_status -eq 0 ]; then
    echo -e "${TICK} File copy from Bastion server to storage complete..."
  else
    echo -e "${CROSS} ${COL_RED}Failed to copy the file from Bastion server to storage.${COL_NC}"
    exit 1
  fi
}


# Generates download URL
generate_download_url() {
  echo -e "${INFO} ${COL_YELLOW}Please test with a curl of the following URL:${COL_NC}"
  echo
  echo -e "${COL_PURPLE}**************************************************************************************************************************************${COL_NC}"
  echo -e "${COL_PURPLE}**************************************************************************************************************************************${COL_NC}"
  echo -e "${COL_GREEN}curl -O ${CDN_DOWNLOAD_URL}$RemoteServerPath/$changedActualFile${COL_NC}"
  echo -e "${COL_PURPLE}**************************************************************************************************************************************${COL_NC}"
  echo -e "${COL_PURPLE}**************************************************************************************************************************************${COL_NC}"
  echo
}


# Function to prompt the user to enter the server name
prompt_server_name() {
    valid_server_name=false
    while [ "$valid_server_name" = false ]; do
        read -p "Enter a three-digit number for the server name (e.g., 025) and press [ENTER]: " ServerNumber
        re='^[0-9]{3}$'
        if [[ $ServerNumber =~ $re ]]; then
            valid_server_name=true
            echo "Entered three-digit number: $ServerNumber"
            echo
        else
            echo -e "${CROSS} ${COL_RED}Invalid input. Please enter a valid three-digit number${COL_NC}"
        fi
    done

    declare -a POP_LIST=("dxa" "dxc" "dxd" "fxa" "fxb" "fxc" "fxd" "fxe" "mxe" "mxw")  # Add your POP names here
    echo "Available POP options:"
    for i in "${!POP_LIST[@]}"; do
        echo "$((i+1)). ${POP_LIST[$i]}"
    done

    valid_pop=false
    while [ "$valid_pop" = false ]; do
        read -n 1 -p "Enter the number of the POP and press [ENTER]: " POPOption
        echo  # Move to a new line after capturing the input character
        case $POPOption in
            [1-9])
                if [ "$POPOption" -le "${#POP_LIST[@]}" ]; then
                    POP="${POP_LIST[$((POPOption-1))]}"
                    valid_pop=true
                    echo
                    echo -e "${INFO} Selected POP: ${COL_CYAN}$POP${COL_NC}"
                else
                    echo -e "${CROSS} ${COL_RED}Invalid input. Please enter a valid number from the list${COL_NC}"
                fi
                ;;
            *)
                echo -e "${CROSS} ${COL_RED}Invalid input. Please enter a valid number from the list${COL_NC}"
                ;;
        esac
    done

    FullServerName="slce${ServerNumber}.${POP}"
    echo -e "${INFO} The generated FullServerName is: ${COL_CYAN}$FullServerName${COL_NC}"
    echo
}


# Function to select a destination from the list of options or manually enter a path
prompt_select_destination() {
    # Define a list of selectable destinations
    declare -a DESTINATIONS=("/files/captures" "/files/disney" "/files/fox") # Add your destination options here

    while true; do
        # Display the numbered list of destination options
        echo "Choose a destination for the file or enter a custom path:"
        for i in "${!DESTINATIONS[@]}"; do
            echo "$((i+1)). ${DESTINATIONS[$i]}"
        done
        echo "0. Enter a custom path"

        # Prompt the user to choose a destination by number or enter a custom path
        read -p "Enter the number of the destination or '0' to enter a custom path and press [ENTER]: " DestinationOption
        echo  # Move to a new line after capturing the input character

        case $DestinationOption in
            [0])
                read -p "Enter the custom path: " CustomPath
                if [ -z "$CustomPath" ]; then
                    echo -e "${CROSS} ${COL_RED}Custom path cannot be empty. Please try again${COL_NC}"
                else
                    RemoteServerPath="$CustomPath"
                    echo "Custom path entered: $RemoteServerPath"
                    echo
                    break
                fi
                ;;
            [1-9])
                if [ "$DestinationOption" -le "${#DESTINATIONS[@]}" ]; then
                    RemoteServerPath="${DESTINATIONS[$((DestinationOption-1))]}"
                    break
                else
                    echo -e "${CROSS} ${COL_RED}Invalid input. Please enter a valid number from the list${COL_NC}"
                fi
                ;;
            *)
                echo -e "${CROSS} ${COL_RED}Invalid input. Please enter a valid number from the list or '0' for a custom path${COL_NC}"
                ;;
        esac
    done
}


# Function to prompt for yes or no input
prompt_yes_no() {
    echo -e -n "${QUESTION} Is the data correct - shall we proceed to the next step? [y/n]: ${COL_NC}"
    while true; do
        read -n 1 -r REPLY
        echo  # Move to a new line after capturing the input character
        case $REPLY in
            [Yy])
                return 0
                ;;
            [Nn])
                return 1
                ;;
            *)
                echo -e "${CROSS} ${COL_RED}Invalid input. Please enter 'y' or 'n'${COL_NC}"
                ;;
        esac
    done
}


# Get user identity and remove unwanted characters from the username
# shellcheck disable=SC1003
User=$(whoami | awk -F '\\' '{print $2}' | tr -d '\r')
echo
echo -e "${INFO} The user is: $User"

# Get ssh key of the user
# shellcheck disable=SC2012
UKey=$(ls "/home/ecdc/$User/.ssh"/id_* 2>/dev/null | head -n 1)
echo -e "${INFO} The user's ssh key is: $UKey"

# Get Random FTP server in prod
FTPServer=$(bselect ftp grq | sort --random-sort | tail -1)
echo -e "${INFO} The random FTP server to be used is: $FTPServer"
echo
echo -e "${ALERT} ${COL_YELLOW}Make sure your key has already been signed by first logging into any slicer!${COL_NC}"
echo
prompt_yes_no # Confirms choice to move on

# Prompt the user to choose how to set FullServerName
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo
    valid_option=false
    while [ "$valid_option" = false ]; do
        echo "Choose how to set source Slicer server:"
        echo " 1) Automatically generate based on server number and POP"
        echo " 2) Manually enter FullServerName"
        echo
        read -p "Enter the number of the option and press [ENTER]: " Option
        echo
        if [[ $Option =~ ^[1-2]$ ]]; then
            valid_option=true
        else
            echo -e "${CROSS} ${COL_RED}Invalid input. Please enter a valid number${COL_NC}"
        fi
    done

    if [ "$Option" -eq 1 ]; then
        prompt_server_name
    else
        read -p "Enter the FullServerName and press [ENTER]: " FullServerName
        echo "Manually entered FullServerName: $FullServerName"
        echo
    fi
else
    echo -e "${INFO} Exiting script..."
    exit 0
fi

valid_response=false
while [ "$valid_response" = false ]; do
    if prompt_yes_no ; then
        echo -e "${INFO} Proceeding with the entered server name: ${COL_CYAN}$FullServerName${COL_NC}"
        echo
        valid_response=true
    else
        echo -e "${CROSS} ${COL_RED}Please re-enter the server name${COL_NC}"
        echo
        # Go back to the server name prompt
        prompt_server_name
    fi
done

# Set the path to place the file on the remote host.
while true; do
    prompt_select_destination
    echo -e "${INFO} The remote storage/CDN endpoint is: ${COL_CYAN}$RemoteServerPath${COL_NC}"
    echo

    if prompt_yes_no ; then
        break
    else
        echo -e "${INFO} Re-selecting the destination..."
        echo
    fi
done

if [ -z "$RemoteServerPath" ]; then
    echo -e "${CROSS} ${COL_RED}Whoops!, you did not enter anything, exiting${COL_NC}"
    exit 1
fi

# Get the file structure and make sure it is not blank
read -p "Enter the slicer file location full path you wish to transfer and press [ENTER] (example: /root/bond0.64_capture.pcap): " PathandFile
echo "You entered: $PathandFile"

if [ -z "$PathandFile" ]; then
    echo -e "${CROSS} ${COL_RED}Whoops!, you did not enter anything, exiting${COL_NC}"
    exit 1
fi

# Get the speed from the user's choice of predefined options
echo "Choose a speed option:"
echo
echo "1) ->  10 Mbps"
echo "2) ->  20 Mbps"
echo "3) ->  30 Mbps"
echo "4) ->  40 Mbps"
echo "5) ->  50 Mbps"
echo "6) ->  60 Mbps"
echo "7) ->  70 Mbps"
echo "8) ->  80 Mbps"
echo "9) ->  90 Mbps"
echo "10) -> 100 Mbps"
echo "20) -> 200 Mbps"
read -p "Enter the number of the speed option and press [ENTER]: " SpeedOption

case $SpeedOption in
    1) Speed=10000 ;;
    2) Speed=20000 ;;
    3) Speed=30000 ;;
    4) Speed=40000 ;;
    5) Speed=50000 ;;
    6) Speed=60000 ;;
    7) Speed=70000 ;;
    8) Speed=80000 ;;
    9) Speed=90000 ;;
    10) Speed=100000 ;;
    20) Speed=200000 ;;
    *) echo -e "${CROSS} ${COL_RED}Invalid speed option selected. Exiting...${COL_NC}" ; exit 1 ;;
esac

# Calculate the speed in Mbps
Mbps_speed=$((Speed / 1000))
echo
echo -e "${INFO} Selected speed is: ${COL_CYAN}$Mbps_speed Mbps${COL_NC}"

# Prompt the user to confirm whether all data is correct before proceeding
prompt_yes_no
# read -p "Are you sure all data is correct? [y/n]: " -n 1 -r
# echo # Move to a new line after capturing the input character

if [[ $REPLY =~ ^[Yy]$ ]]; then
    ActualFile=$(echo "$PathandFile" | awk -F "/" '{print $NF}')
    changedActualFile="$(date +"%H-%M_%d-%m-%Y")$ActualFile"

    # Move file from the slicer to the bastion server
    slicer_to_bastion
    echo

    # Transfer the file from the bastion server to the user's local storage / CDN endpoint
    bastion_to_storage
    echo

    # Generate a download url that the user can cURL from their storage location
    generate_download_url
    echo

    # Prompt for file deletion
    read -p "Would you like to delete the file from bast to keep things clean? [y/n] " -n 1 -r
    echo # Move to a new line after capturing the input character

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm "/home/ecdc/$User/$changedActualFile"
        echo
        echo -e "${TICK} ${COL_CYAN}File deleted from the bastion server${COL_NC}"
        echo
    else
        echo
        echo -e "${CROSS} ${COL_RED}File will not be deleted${COL_NC}"
        echo
    fi
fi
