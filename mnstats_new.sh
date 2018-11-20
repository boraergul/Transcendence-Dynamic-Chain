#!/bin/bash

list=($(ls -la /usr/share | grep "\.transcendence" | cut -d "." -f 2 | cut -d "_" -f 2))
for i in ${!list[@]}; do
  /usr/bin/transcendence-cli_${list[$i]}.sh masternode status &>/dev/null
  if [[ $? == 0 ]]
  then
    result=$(/usr/bin/transcendence-cli_${list[$i]}.sh masternode status | grep message |cut -d ":" -f 2)
  else
    /usr/bin/transcendence-cli_${list[$i]}.sh masternode status 2> /tmp/errorout
    result=$(cat /tmp/errorout)
  fi
  echo "  ${list[$i]} -- $result"
done
rm -f /tmp/errorout
