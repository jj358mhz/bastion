#!/bin/bash
# Variables
CLOUD_POPS=( 'dsa' 'dsb' 'fxb' 'fxc' 'fxd' 'fxe' 'fxy' 'mse' 'msw' 'wcf' )
ALLOWED_USERNAMES=( 'root' 'manager' 'app_support' 'staging' 'liveops' )

# -- DO NOT MODIFY BELOW THIS LINE --
POP=$(echo "$1" | awk -F "." '{print $2}')
USERNAME=$(echo "$1" | awk -F "@" '{print $1}')
SLICER=$(echo "$1" | awk -F "@" '{print $2}'| sed -E 's/\..*$//')
DOMAIN=$(echo "$1" | awk -F "@" '{print $2}'| sed -E 's/^.*\.//')".edgecastcdn.net"
SSH_OPTS='-4 -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EXECUTOR=$(echo ${USER})
EXEC_FROM=$(echo ${HOSTNAME})
readonly SCRIPT_NAME=$(basename $0)

# Colorize
CYAN="\033[36m"
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"

source /EdgeCast/bast/helper_scripts/shell_lib.sh  # Re-usable shell functions

usage () {
    >&2 echo -e "${CYAN}Example usage:${RESET}"
    >&2 echo -e "For direct access to a server use: ${GREEN} ${SCRIPT_NAME} <username>@slce001.<pop> ${RESET} "
    >&2 echo -e "To only run a command on a remote server add it after: ${GREEN}${SCRIPT_NAME} <username>@slce001.<pop> 'uptime' ${RESET}"
    >&2 echo -e "You can also use this for batching commands for example: ${GREEN}for i in \`seq -w 001 025\` ; do ${SCRIPT_NAME} <username>@slce\${i}.<pop> 'uname -r' ; done ${RESET}"
    >&2 echo " "
    exit 1
    }

### Logger
readonly REMOTE_LOGGER="logger --id -p user.notice -t ${SCRIPT_NAME} [${EXECUTOR}@${EXEC_FROM}] \(${USERNAME}\) CMD \(\"${*:2}\"\)"

log() {
    logger --id -p user.notice -t ${SCRIPT_NAME} "(${EXECUTOR}) CMD (ssh ${*})"
}

err() {
    echo "${@}" >&2
    logger --id -p user.error -t ${SCRIPT_NAME} "(${EXECUTOR}) [ERROR] CMD (ssh ${*})"
}

###

if ! [[  $1 == *"@"* ]]; then
    echo -e  "${RED} ${BOLD}** ERROR: Missing username and/or arguments.${RESET}"
    err "${@}"
    usage
fi

if ! [[ " ${ALLOWED_USERNAMES[@]} " =~ " ${USERNAME} " ]] ; then
    echo -e  "${RED} ${BOLD}** ERROR: Invalid username.${RESET}"
    err "${@}"
    usage
fi

if [[ -n $2 ]] ; then
    CMD="${REMOTE_LOGGER} && ${*:2}"
    LABEL="| sed \"s/^/${SLICER}.${POP} /g\"  | sed  ''/${SLICER}.${POP}/s//`printf "${GREEN}${SLICER}.${POP}${RESET}:"`/''"
fi


# SSHCA Principals to be signed:
SSHCA_PRINCIPAL="slicer_${USERNAME}"
ensure_signed_key "${SSHCA_PRINCIPAL}"


ssh_direct () {
    ssh ${SSH_OPTS} ${USERNAME}@${SLICER}.${DOMAIN} ${CMD} ${LABEL}
}

ssh_cloud () {
    ssh ${SSH_OPTS} -o ProxyCommand="ssh -q -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null -W %h:%p ${USERNAME}@bast.${DOMAIN}" ${USERNAME}@${SLICER}.${DOMAIN} ${CMD} ${LABEL}
}

if [[  ${SLICER} =~ ^slce[0-9][0-9][0-9].*$ ]]; then
    log "${@}"
    if [[ " ${CLOUD_POPS[@]} " =~ " ${POP} " ]]; then
        ssh_cloud
    else
        ssh_direct
    fi
    exit
else
    err "${@}"
    usage
fi
exit
