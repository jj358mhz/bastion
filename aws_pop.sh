#!/bin/bash

if [[ ! $1 =~ ^slce[0-9][0-9][0-9].(fxb|fxc|fxd|fxe|dsa|dsb)$ ]]; then
  >&2 echo "Example usage:"
    >&2 echo "  $0 slce001.fxc"
      exit 1
      fi

      SLICER=$(echo $1 | sed -E 's/\..*$//')
      DOMAIN="$(echo $1 | sed -E 's/^.*\.//').edgecastcdn.net"

      SSH_KEY="/EdgeCast/admin/.ssh/manager.id_rsa"

      sudo ssh -i "${SSH_KEY}" -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" \
            -o ProxyCommand="sudo ssh -i ${SSH_KEY} -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' \
          -W %h:%p ubuntu@bast.${DOMAIN}" "ubuntu@${SLICER}.${DOMAIN}"
