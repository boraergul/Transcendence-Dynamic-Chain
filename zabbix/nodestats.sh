#!/bin/bash
/usr/bin/transcendence-cli_$1.sh masternode status &>/dev/null
if [[ $? == 0 ]]
then
  result=$(/usr/bin/transcendence-cli_$1.sh masternode status | grep status |cut -d ":" -f 2 | sed 's/,//')
else
  /usr/bin/transcendence-cli_$1.sh masternode status 2> /tmp/errorout
  result=999
fi
echo "$result"
