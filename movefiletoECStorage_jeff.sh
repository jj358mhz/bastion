#!/usr/bin/env bash
# Bastion script to easily pull files (logs, captures, etc., off slicer servers)

CDNUser="jjohnston@edg.io@rsync.vny.EEA8.labcdn.com:"
CDNDownloadURL="http://cdn.telcomjj.com"

# Function to prompt the user to enter the server name
prompt_server_name() {
    valid_server_name=false
    while [ "$valid_server_name" = false ]; do
        read -p "Enter a three-digit number for the server name (e.g., 025) and press [ENTER]: " ServerNumber
        re='^[0-9]{3}$'
        if [[ $ServerNumber =~ $re ]]; then
            valid_server_name=true
            echo "Entered three-digit number: $ServerNumber"
            echo ""
        else
            echo "Invalid input. Please enter a valid three-digit number."
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
        echo ""  # Move to a new line after capturing the input character
        case $POPOption in
            [1-9])
                if [ "$POPOption" -le "${#POP_LIST[@]}" ]; then
                    POP="${POP_LIST[$((POPOption-1))]}"
                    valid_pop=true
                    echo "Selected POP: $POP"
                    echo ""
                else
                    echo "Invalid input. Please enter a valid number from the list."
                fi
                ;;
            *)
                echo "Invalid input. Please enter a valid number from the list."
                ;;
        esac
    done

    FullServerName="slce${ServerNumber}.${POP}"
    echo "The generated FullServerName is: $FullServerName"
    echo ""
}

# Get user identity and remove unwanted characters from the username
User=$(whoami | awk -F '\\' '{print $2}' | tr -d '\r')
echo "The user is: $User"
echo ""

# Get ssh key of the user
UKey=$(ls "/home/ecdc/$User/.ssh"/id_* 2>/dev/null | head -n 1)
echo "The user ssh key is: $UKey"
echo ""

# Get Random FTP server in prod
FTPServer=$(bselect ftp grq | sort --random-sort | tail -1)
echo "The random FTP server to be used is: $FTPServer"
echo ""

echo "Make sure your key has already been signed!"
read -p "Do you want to continue? [y/n]: " -n 1 -r
echo    # (optional) move to a new line

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "yes"
    # Prompt the user to choose how to set FullServerName
    valid_option=false
    while [ "$valid_option" = false ]; do
        echo "Choose how to set FullServerName:"
        echo "1) Automatically generate based on server number and POP"
        echo "2) Manually enter FullServerName"
        read -p "Enter the number of the option and press [ENTER]: " Option
        if [[ $Option =~ ^[1-2]$ ]]; then
            valid_option=true
        else
            echo "Invalid input. Please enter a valid number."
        fi
    done

    if [ "$Option" -eq 1 ]; then
        prompt_server_name
    else
        read -p "Enter the FullServerName and press [ENTER]: " FullServerName
        echo "Manually entered FullServerName: $FullServerName"
        echo ""
    fi
fi

echo "Entered server name: $FullServerName"

valid_response=false
while [ "$valid_response" = false ]; do
    read -n 1 -p "Is this correct? [y/n]: " -r
    echo ""  # Move to a new line after capturing the input character
    case $REPLY in
        [Yy])
            echo "Proceeding with the entered server name."
            echo ""
            valid_response=true
            ;;
        [Nn])
            echo "Please re-enter the server name."
            echo ""
            valid_response=true
            # Go back to the server name prompt
            prompt_server_name
            ;;
        *)
            echo "Invalid input. Please enter 'y' or 'n'."
            ;;
    esac
done

# Set the path to place the file on the remote host.
read -p "Enter the remote CDN endpoint path where the file is to be placed and press [ENTER] (e.g. /files/disney): " RemoteServerPath
echo ""
echo "$RemoteServerPath"

if [ -z "$RemoteServerPath" ]; then
    echo "Whoops!, you did not enter anything, exiting"
    exit 1
fi

# Get the file structure and make sure it is not blank
echo "Example of the path would be /var/Edgecast/logs/uplynk/uplynk_liveslicer-kcpq_fxb_p.log.tar.bz2"
echo ""
read -p "Enter the full path of the location of the file you would like to move and press [ENTER]: " PathandFile
echo "$PathandFile"

if [ -z "$PathandFile" ]; then
    echo "Whoops!, you did not enter anything, exiting"
    exit 1
fi

# Get the speed from the user's choice of predefined options
echo "Choose a speed option:"
echo "1) 10000 kbits/s"
echo "2) 20000 kbits/s"
echo "3) 30000 kbits/s"
echo "4) 40000 kbits/s"
echo "5) 50000 kbits/s"
echo "6) 60000 kbits/s"
echo "7) 70000 kbits/s"
echo "8) 80000 kbits/s"
echo "9) 90000 kbits/s"
echo "10) 100000 kbits/s"
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
    *) echo "Invalid speed option selected. Exiting." ; exit 1 ;;
esac

echo "$Speed kbits/s"
read -p "Are you sure all data is correct? [y/n]: " -n 1 -r

if [[ $REPLY =~ ^[Yy]$ ]]; then
    ActualFile=$(echo "$PathandFile" | awk -F "/" '{print $NF}')
    changedActualFile="$(date +"%H-%M_%d-%m-%Y")$ActualFile"
    /usr/bin/scp -4 -l "$Speed" -i "$UKey" "root@$FullServerName:$PathandFile" "/home/ecdc/$User/$changedActualFile"
    echo "File Complete"
    echo "Moving file to Storage"
    /usr/bin/scp -4 -i "$UKey" "/home/ecdc/$User/$changedActualFile" "$CDNUser$RemoteServerPath"
    echo ""
    echo "The file has been moved"
    echo ""
    echo "Please test with a curl:"
    echo ""
    echo "curl -O $CDNDownloadURL$RemoteServerPath/$changedActualFile"
    echo ""
    read -p "Would you like to delete the file from bast to keep things clean? [y/n] " -n 1 -r

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm "/home/ecdc/$User/$changedActualFile"
        echo "\n"
    fi
fi
