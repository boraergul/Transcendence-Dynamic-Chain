#/bin/bash
cd ~
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
IP6=(curl -s4 v6.ipv6-test.com/api/myip.php)
if [[ $(lsb_release -d) != *16.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
  exit 1
fi
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi
if grep -qF "inet6" /etc/network/interfaces
then
   IP6SET="y"
else
   IP6SET="n"
fi
if [ $IP6SET = "n" ]
then
  face="$(lshw -C network | grep "logical name:" | sed -e 's/logical name:/logical name: /g' | awk '{print $3}')"
  echo "iface $face inet6 static" >> /etc/network/interfaces
  echo "address $IP6" >> /etc/network/interfaces
  echo "netmask 64" >> /etc/network/interfaces
fi
face="$(lshw -C network | grep "logical name:" | sed -e 's/logical name:/logical name: /g' | awk '{print $3}')"
gateway1=$(/sbin/route -A inet6 | grep -w "$face")
gateway2=${gateway1:0:26}
gateway3="$(echo -e "${gateway2}" | tr -d '[:space:]')"
if [[ $gateway3 = *"128"* ]]; then
  gateway=${gateway3::-5}
fi
if [[ $gateway3 = *"64"* ]]; then
  gateway=${gateway3::-3}
fi
IP4COUNT=$(find /usr/share/.transcendence_* -maxdepth 0 -type d | wc -l)
function configure_systemd() {
  cat << EOF > /etc/systemd/system/transcendenced$ALIAS.service
[Unit]
Description=transcendenced$ALIAS service
After=network.target
 [Service]
User=root
Group=root
 Type=forking
#PIDFile=/var/run/.transcendence_$ALIAS.pid
 ExecStart=/usr/bin/transcendenced_$ALIAS.sh
ExecStop=-/usr/bin/transcendence-cli_$ALIAS.sh stop
 Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
 [Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  sleep 6
  crontab -l > cron$ALIAS
  echo "@reboot systemctl start transcendenced$ALIAS" >> cron$ALIAS
  crontab cron$ALIAS
  rm cron$ALIAS
  systemctl start transcendenced$ALIAS.service
}
IP4=$(curl -s4 api.ipify.org)
perl -i -ne 'print if ! $a{$_}++' /etc/network/interfaces
if [ ! -d "/root/bin" ]; then
 DOSETUP="y"
else
 DOSETUP="n"
fi
clear
echo "1 - Create new nodes"
echo "2 - Remove an existing node"
echo "3 - Upgrade an existing node"
echo "4 - List aliases"
echo "What would you like to do?"
read DO
echo ""
if [ $DO = "4" ]
then
ALIASES=$(find /usr/share/.transcendence_* -maxdepth 0 -type d | cut -c22-)
echo -e "${GREEN}${ALIASES}${NC}"
echo ""
echo "1 - Create new nodes"
echo "2 - Remove an existing node"
echo "3 - Upgrade an existing node"
echo "4 - List aliases"
echo "What would you like to do?"
read DO
echo ""
fi
if [ $DO = "3" ]
then
perl -i -ne 'print if ! $a{$_}++' /etc/monit/monitrc >/dev/null 2>&1
echo "Enter the alias of the node you want to upgrade"
read ALIAS
  echo -e "Upgrading ${GREEN}${ALIAS}${NC}. Please wait."
  sed -i '/$ALIAS/d' .bashrc
  sleep 1
  ## Config Alias
  echo "alias ${ALIAS}_status=\"transcendence-cli -datadir=/usr/share/.transcendence_$ALIAS masternode status\"" >> .bashrc
  echo "alias ${ALIAS}_stop=\"transcendence-cli -datadir=/usr/share/.transcendence_$ALIAS stop && systemctl stop transcendenced$ALIAS\"" >> .bashrc
  echo "alias ${ALIAS}_start=\"/usr/bin/transcendenced_${ALIAS}.sh && systemctl start transcendenced$ALIAS\""  >> .bashrc
  echo "alias ${ALIAS}_config=\"nano /usr/share/.transcendence_${ALIAS}/transcendence.conf\""  >> .bashrc
  echo "alias ${ALIAS}_getinfo=\"transcendence-cli -datadir=/usr/share/.transcendence_$ALIAS getinfo\"" >> .bashrc
cat << 'EOF' > /usr/bin/mnstats
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
EOF
  chmod +x /usr/bin/mnstats
  configure_systemd
  sleep 1
  source .bashrc
  echo -e "${GREEN}${ALIAS}${NC} Successfully upgraded."
fi
if [ $DO = "2" ]
then
perl -i -ne 'print if ! $a{$_}++' /etc/monit/monitrc >/dev/null 2>&1
echo "Input the alias of the node that you want to delete"
read ALIASD
echo ""
echo -e "${GREEN}Deleting ${ALIASD}${NC}. Please wait."
## Removing service
systemctl stop transcendenced$ALIASD >/dev/null 2>&1
systemctl disable transcendenced$ALIASD >/dev/null 2>&1
rm /etc/systemd/system/transcendenced${ALIASD}.service >/dev/null 2>&1
systemctl daemon-reload >/dev/null 2>&1
systemctl reset-failed >/dev/null 2>&1
## Stopping node
transcendence-cli -datadir=/usr/share/.transcendence_$ALIASD stop >/dev/null 2>&1
sleep 5
## Removing monit and directory
rm /usr/share/.transcendence_$ALIASD -r >/dev/null 2>&1
sed -i '/$ALIASD/d' .bashrc >/dev/null 2>&1
sleep 1
sed -i '/$ALIASD/d' /etc/monit/monitrc >/dev/null 2>&1
sed -i '/#$ALIASD/d' /etc/network/interfaces >/dev/null 2>&1
monit reload >/dev/null 2>&1
sed -i '/$ALIASD/d' /etc/monit/monitrc >/dev/null 2>&1
crontab -l -u root | grep -v transcendenced$ALIASD | crontab -u root - >/dev/null 2>&1
source .bashrc
echo -e "${ALIASD} Successfully deleted."
fi
if [ $DO = "1" ]
then
echo "1 - Easy mode"
echo "2 - Expert mode"
echo "Please select a option:"
read EE
echo ""
if [ $EE = "1" ] 
then
MAXC="32"
fi
if [ $EE = "2" ] 
then
echo ""
echo "Enter max connections value"
read MAXC
echo ""
echo "Enter SWAP size (For 2 GB enter only 2)"
read SS
swapsize=$(expr $SS \* 1000)
fi
if [ $DOSETUP = "y" ]
then
  echo -e "Installing ${GREEN}Transcendence dependencies${NC}. Please wait."
  sudo apt-get update 
  sudo apt-get -y upgrade
  sudo apt-get -y dist-upgrade
  sudo apt-get update
  sudo apt-get install -y zip unzip bc curl nano lshw
  cd /var
  sudo touch swap.img
  sudo chmod 600 swap.img
  sudo dd if=/dev/zero of=/var/swap.img bs=1024k count=$swapsize
  sudo mkswap /var/swap.img 
  sudo swapon /var/swap.img 
  sudo free 
  sudo echo "/var/swap.img none swap sw 0 0" >> /etc/fstab
  cd
 if [ ! -f Linux.zip ]
  then
  wget https://github.com/phoenixkonsole/transcendence/releases/download/v1.1.0.0/Linux.zip
 fi
  unzip Linux.zip 
  chmod +x Linux/bin/* 
  sudo mv  Linux/bin/* /usr/bin/
  rm -rf Linux.zip Windows Linux Mac
  sudo apt-get install -y ufw 
  sudo ufw allow ssh/tcp 
  sudo ufw limit ssh/tcp 
  sudo ufw logging on
  echo "y" | sudo ufw enable 
  echo 'export PATH=/usr/bin:$PATH' > ~/.bash_aliases
  source ~/.bashrc
  echo ""
fi
if [ ! -f DynamicChain.zip ]
then
wget https://github.com/murtzsarialtun/Transcendence-Dynamic-Chain/releases/download/1.2.1/DynamicChain.zip
fi
echo -e "Telos nodes currently installed: ${GREEN}${IP4COUNT}${NC}"
if [ $IP4COUNT = "0" ]
then
 echo ""
 echo "1 - ipv4"
 echo "2 - ipv6"
 echo "What interface would you like to use? (ipv4 only supports one node)"
 read INTR
fi
if [ $IP4COUNT != "0" ]
then
 INTR=2
fi
if [ $INTR = "1" ]
then
 PORT=22123
 PORTD=22123
 RPCPORT=221230
  echo ""
  echo "Enter alias for new node"
  read ALIAS
  CONF_DIR=/usr/share/.transcendence_$ALIAS
  echo ""
  echo "Enter masternode private key for node $ALIAS"
  read PRIVKEY
  if [ $EE = "2" ] 
	then
	echo ""
	echo "Enter port for $ALIAS"
	read PORTD
  fi
  mkdir /usr/share/.transcendence_$ALIAS
  unzip DynamicChain.zip -d /usr/share/.transcendence_$ALIAS >/dev/null 2>&1
  echo '#!/bin/bash' > /usr/bin/transcendenced_$ALIAS.sh
  echo "transcendenced -daemon -conf=$CONF_DIR/transcendence.conf -datadir=$CONF_DIR "'$*' >> /usr/bin/transcendenced_$ALIAS.sh
  echo '#!/bin/bash' > /usr/bin/transcendence-cli_$ALIAS.sh
  echo "transcendence-cli -conf=$CONF_DIR/transcendence.conf -datadir=$CONF_DIR "'$*' >> /usr/bin/transcendence-cli_$ALIAS.sh
  echo '#!/bin/bash' > /usr/bin/transcendence-tx_$ALIAS.sh
  echo "transcendence-tx -conf=$CONF_DIR/transcendence.conf -datadir=$CONF_DIR "'$*' >> /usr/bin/transcendence-tx_$ALIAS.sh
  chmod 755 /usr/bin/transcendence*.sh
  mkdir -p $CONF_DIR
  echo "rpcuser=user"`shuf -i 100000-10000000 -n 1` >> transcendence.conf_TEMP
  echo "rpcpassword=pass"`shuf -i 100000-10000000 -n 1` >> transcendence.conf_TEMP
  echo "rpcallowip=127.0.0.1" >> transcendence.conf_TEMP
  echo "rpcport=$RPCPORT" >> transcendence.conf_TEMP
  echo "listen=1" >> transcendence.conf_TEMP
  echo "server=1" >> transcendence.conf_TEMP
  echo "daemon=1" >> transcendence.conf_TEMP
  echo "logtimestamps=1" >> transcendence.conf_TEMP
  echo "maxconnections=$MAXC" >> transcendence.conf_TEMP
  echo "masternode=1" >> transcendence.conf_TEMP
  echo "dbcache=20" >> transcendence.conf_TEMP
  echo "maxorphantx=10" >> transcendence.conf_TEMP
  echo "maxmempool=100" >> transcendence.conf_TEMP
  echo "banscore=10" >> transcendence.conf_TEMP
  echo "" >> transcendence.conf_TEMP
  echo "" >> transcendence.conf_TEMP
  echo "addnode=127.0.0.1" >> transcendence.conf_TEMP
  echo "port=$PORTD" >> transcendence.conf_TEMP
  echo "masternodeaddr=$IP4:$PORT" >> transcendence.conf_TEMP
  echo "masternodeprivkey=$PRIVKEY" >> transcendence.conf_TEMP
  sudo ufw allow 22123/tcp
  mv transcendence.conf_TEMP $CONF_DIR/transcendence.conf
  echo ""
  echo -e "Your ip is ${GREEN}$IP4:$PORT${NC}"
	echo "alias ${ALIAS}_status=\"transcendence-cli -datadir=/usr/share/.transcendence_$ALIAS masternode status\"" >> .bashrc
	echo "alias ${ALIAS}_stop=\"systemctl stop transcendenced$ALIAS\"" >> .bashrc
	echo "alias ${ALIAS}_start=\"systemctl start transcendenced$ALIAS\""  >> .bashrc
	echo "alias ${ALIAS}_config=\"nano /usr/share/.transcendence_${ALIAS}/transcendence.conf\""  >> .bashrc
	echo "alias ${ALIAS}_getinfo=\"transcendence-cli -datadir=/usr/share/.transcendence_$ALIAS getinfo\"" >> .bashrc
	echo "alias ${ALIAS}_resync=\"/usr/bin/transcendenced_$ALIAS.sh -resync\"" >> .bashrc
	echo "alias ${ALIAS}_reindex=\"/usr/bin/transcendenced_$ALIAS.sh -reindex\"" >> .bashrc
	echo "alias ${ALIAS}_restart=\"systemctl restart transcendenced$ALIAS\""  >> .bashrc

cat << 'EOF' > /usr/bin/mnstats
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
EOF

chmod +x /usr/bin/mnstats

	## Config Systemctl
	configure_systemd
fi
if [ $INTR = "2" ]
then
echo ""
echo "How many nodes do you want to install on this server?"
read MNCOUNT
let COUNTER=0
let MNCOUNT=MNCOUNT+IP4COUNT
let COUNTER=COUNTER+IP4COUNT
while [  $COUNTER -lt $MNCOUNT ]; do
 PORT=22123
 PORTD=$((22123+$COUNTER))
 RPCPORTT=$(($PORT*10))
 RPCPORT=$(($RPCPORTT+$COUNTER))
 COUNTER=$((COUNTER+1))
  echo ""
  echo "Enter alias for new node"
  read ALIAS
  CONF_DIR=/usr/share/.transcendence_$ALIAS
  echo ""
  echo "Enter masternode private key for node $ALIAS"
  read PRIVKEY
  if [ $EE = "2" ] 
	then
	echo ""
	echo "Enter port for $ALIAS"
	read PORTD
  fi
  mkdir /usr/share/.transcendence_$ALIAS
  unzip DynamicChain.zip -d /usr/share/.transcendence_$ALIAS >/dev/null 2>&1
  echo '#!/bin/bash' > /usr/bin/transcendenced_$ALIAS.sh
  echo "transcendenced -daemon -conf=$CONF_DIR/transcendence.conf -datadir=$CONF_DIR "'$*' >> /usr/bin/transcendenced_$ALIAS.sh
  echo '#!/bin/bash' > ~/bin/transcendence-cli_$ALIAS.sh
  echo "transcendence-cli -conf=$CONF_DIR/transcendence.conf -datadir=$CONF_DIR "'$*' >> /usr/bin/transcendence-cli_$ALIAS.sh
  echo '#!/bin/bash' > /usr/bin/transcendence-tx_$ALIAS.sh
  echo "transcendence-tx -conf=$CONF_DIR/transcendence.conf -datadir=$CONF_DIR "'$*' >> /usr/bin/transcendence-tx_$ALIAS.sh
  chmod 755 /usr/bin/transcendence*.sh
  mkdir -p $CONF_DIR
  echo "rpcuser=user"`shuf -i 100000-10000000 -n 1` >> transcendence.conf_TEMP
  echo "rpcpassword=pass"`shuf -i 100000-10000000 -n 1` >> transcendence.conf_TEMP
  echo "rpcallowip=127.0.0.1" >> transcendence.conf_TEMP
  echo "rpcport=$RPCPORT" >> transcendence.conf_TEMP
  echo "listen=1" >> transcendence.conf_TEMP
  echo "server=1" >> transcendence.conf_TEMP
  echo "daemon=1" >> transcendence.conf_TEMP
  echo "logtimestamps=1" >> transcendence.conf_TEMP
  echo "maxconnections=$MAXC" >> transcendence.conf_TEMP
  echo "masternode=1" >> transcendence.conf_TEMP
  echo "dbcache=20" >> transcendence.conf_TEMP
  echo "maxorphantx=10" >> transcendence.conf_TEMP
  echo "maxmempool=100" >> transcendence.conf_TEMP
  echo "banscore=10" >> transcendence.conf_TEMP
  echo "" >> transcendence.conf_TEMP
  echo "" >> transcendence.conf_TEMP
  echo "addnode=127.0.0.1" >> transcendence.conf_TEMP
  echo "port=$PORTD" >> transcendence.conf_TEMP
  echo "masternodeaddr=[${gateway}$COUNTER]:$PORT" >> transcendence.conf_TEMP
  echo "masternodeprivkey=$PRIVKEY" >> transcendence.conf_TEMP
  sudo ufw allow 22123/tcp >/dev/null 2>&1
  mv transcendence.conf_TEMP $CONF_DIR/transcendence.conf
  echo ""
  echo -e "Your ip is ${GREEN}[${gateway}$COUNTER]:${PORT}${NC}"
	echo "alias ${ALIAS}_status=\"transcendence-cli -datadir=/usr/share/.transcendence_$ALIAS masternode status\"" >> .bashrc
	echo "alias ${ALIAS}_stop=\"systemctl stop transcendenced$ALIAS\"" >> .bashrc
	echo "alias ${ALIAS}_start=\"systemctl start transcendenced$ALIAS\""  >> .bashrc
	echo "alias ${ALIAS}_config=\"nano /usr/share/.transcendence_${ALIAS}/transcendence.conf\""  >> .bashrc
	echo "alias ${ALIAS}_getinfo=\"transcendence-cli -datadir=/usr/share/.transcendence_$ALIAS getinfo\"" >> .bashrc
	echo "alias ${ALIAS}_resync=\"/usr/bin/transcendenced_$ALIAS.sh -resync\"" >> .bashrc
	echo "alias ${ALIAS}_reindex=\"/usr/bin/transcendenced_$ALIAS.sh -reindex\"" >> .bashrc
	echo "alias ${ALIAS}_restart=\"systemctl restart transcendenced$ALIAS\""  >> .bashrc

cat << 'EOF' > /usr/bin/mnstats
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
EOF

chmod +x /usr/bin/mnstats

	## Config Systemctl
	configure_systemd
done
fi
echo ""
echo "Commands:"
echo "ALIAS_start"
echo "ALIAS_stop"
echo "ALIAS_restart"
echo "ALIAS_status"
echo "ALIAS_config"
echo "ALIAS_getinfo"
echo "ALIAS_resync"
echo "ALIAS_reindex"
echo "mnstats"
fi
echo ""
echo "Made by Kriptoman"
echo "Transcendence donations: GPN1TfeKBr4CN2b4znigohGf1bLxoxLNVP"
exec bash
exit
