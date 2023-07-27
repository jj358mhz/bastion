#!/usr/bin/env bash
# Bastion script to easily pull files (logs, captures, etc., off slicer servers)

CDNUser="jjohnston@edg.io@rsync.vny.EEA8.labcdn.com:"
CDNDownloadURL="http://cdn.telcomjj.com"

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
    # Get the server name and check dns before proceeding.
    read -p "Enter the server that the file is located on and press [ENTER]: " ServerName
    echo "$ServerName"
    ip=$(nslookup "$ServerName" | egrep "Address:" | tail -1 | awk -F " " '{print $NF}')
    fqdn=$(nslookup "$ServerName" | grep Name | tail -1 | awk -F " " '{print $NF}')
    if [[ "$fqdn" == "$ServerName.edgecastcdn.net" ]]; then
        echo "Pass"
    else
        echo "I cannot find that DNS record, exiting."
        exit 1
    fi
    # Set the path to place file on remote host.
    read -p "Enter the remote cdn endpoint path where the file is to be placed and press [ENTER] (i.e. /fox/for_download/for_pavel): " RemoteServerPath
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

    # Get the speed from user's choice of predefined options
    echo "Choose a speed option:"
    echo "1) 10000 kbits/s"
    echo "2) 20000 kbits/s"
    echo "3) 30000 kbits/s"
    echo "4) 40000 kbits/s"
    echo "5) 50000 kbits/s"
    read -p "Enter the number of the speed option and press [ENTER]: " SpeedOption

    case $SpeedOption in
        1) Speed=10000 ;;
        2) Speed=20000 ;;
        3) Speed=30000 ;;
        4) Speed=40000 ;;
        5) Speed=50000 ;;
        *) echo "Invalid speed option selected. Exiting." ; exit 1 ;;
    esac

    echo "$Speed kbits/s"
    read -p "Are you sure all data is correct? [y/n]: " -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ActualFile=$(echo "$PathandFile" | awk -F "/" '{print $NF}')
        changedActualFile="$(date +"%H-%M_%d-%m-%Y")$ActualFile"
        /usr/bin/scp -4 -l "$Speed" -i "$UKey" "root@$ServerName:$PathandFile" "/home/ecdc/$User/$changedActualFile"
        echo "File Complete"
        echo "Moving file to Storage"
        # /usr/bin/scp -4 -i /home/ecdc/$User/.ssh/$UKey /home/ecdc/$User/$changedActualFile root@$FTPServer:/EC_Storage/grq001/1176C/appsupport/
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
fi
