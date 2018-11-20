#!/bin/bash

/usr/bin/transcendence-cli_$1.sh masternode stop

sleep 5

/usr/bin/transcendence-cli_$1.sh masternode start

