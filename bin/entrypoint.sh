#!/bin/bash
set -e

COMMAND=${1}

IFS=$'\n'
for line in $(terrafying); do
  terra_pattern="terrafying ${COMMAND} "
  if [[ $line =~ $terra_pattern ]]; then
    terraform init
    exec terrafying ${@}
  fi
done

exec ${@}
