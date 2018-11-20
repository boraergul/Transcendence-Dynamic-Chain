#!/bin/bash

list=($(ls -la /root | grep "\.transcendence" | cut -d "." -f 2 | cut -d "_" -f 2))
for i in ${!list[@]}; do
  /root/bin/transcendence-cli_${list[$i]}.sh masternode status &>/dev/null
  if [[ $? == 0 ]]
  then
    result=$(/root/bin/transcendence-cli_${list[$i]}.sh masternode status | grep message |cut -d ":" -f 2)
  else
    /root/bin/transcendence-cli_${list[$i]}.sh masternode status 2> /tmp/errorout
    result=$(cat /tmp/errorout)
  fi
  echo "  ${list[$i]} -- $result"
done
rm -f /tmp/errorout
