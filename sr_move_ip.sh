#! /bin/bash
# set -x
# SAP HANA System Replication handle virtual IP 
# Design by Uwe Kaden uwe.kaden@allianz.com
# for HANA System replication only
# Remarks:
# 
# ip addr add 10.16.75.230/22 dev eth0 label eth0:9
# ip addr del 10.16.75.230/22 dev eth0 label eth0:9
#
# defining Variables
#########################################################################################

#########################################################################################
###                             CUSTOMIZING SECTION START                             ###

SID=BGP
INSTNO=30
VIPL="10.16.75.230/22"
SERVER1=sla70076
SERVER2=sla70075


###                             CUSTOMIZING SECTION END                              ####
#########################################################################################
#########################################################################################
###                                                                                   ###
###                           !DO NOT TOUCH VALUES BELOW!                             ###
###                                                                                   ###
#########################################################################################

SIDADM=$(echo ${SID} | tr '[:upper:]' '[:lower:]' )"adm"
VIP=$(echo ${VIPL} |  awk -F"/" '{print $1}')
LHOST=$(hostname)
LBL="eth0:9"
DEV=$(ip add | grep 10.16 | grep "global eth" | awk '{print $7}')
ALIVE=0
DOWN=0
#########################################################################################
###                                                                                   ###
###                               Code starts here                                    ###
###                                                                                   ###
#########################################################################################

is_alive () {

ping -c 4 ${VIP} > /dev/null

if [ "$?" -eq 0 ]; then
   ip add | grep -w "${VIP}" > /dev/null 2>&1
   if [ "$?" -eq 0 ]; then
      echo "This host has the IP connected"
	  VIF=$(ip add | grep -w ${VIP} | awk '{print $6}')
	  DEV=$(echo ${VIF} | awk -F":" '{print $1}')
	  ALIVE=1
   else
      echo "IP is up, but not on this server. Please check other host"
   fi	  
else
   DOWN=1
   echo "IP is not reachable. This server is acting as ${SRMODE}"
fi   

}



remove_ip () {

# Check whether IP is alive 
# Check whether we are on the correct host
is_alive
if [ "${ALIVE}" -eq 1 ]; then
    ip addr del ${VIPL} dev ${DEV} label ${VIF}
else
   echo "Cannot remove ip. Check option -c"
fi   
is_alive
}



add_ip () {
# Check whether IP is alive 
# Check whether we are on the correct host
echo "Calling is_alive"
is_alive
if [ "${DOWN}" -eq 1 ]; then
    ip addr add ${VIPL} dev ${DEV} label ${LBL}
	echo "Calling is_alive"
is_alive  
else
   echo "Cannot add ip. Check option -c"
fi   

}



is_allowed () {
declare -a SYSTEMS=("${SERVER2}" "${SERVER1}")

if [[ " ${SYSTEMS[@]} " =~ " ${LHOST} " ]]; then
   echo "Allowed to handle ${VIP} on this host."
else
   echo "Sorry, host ${LHOST} is not allowed for SAP HANA instance ${SID}"
   exit 1
fi
 
 }
 
 check_sap () {
 # Expecting GREEN in UP if its running 
 UP=$(echo -e $(su - ${SIDADM} -c "sapcontrol -nr ${INSTNO} -function GetSystemInstanceList")| tr -d ',' | awk -F"[ ]" '{ print $18}')
 # Find the systems instance server name
 SAPHOST=$(echo -e $(su - ${SIDADM} -c "sapcontrol -nr ${INSTNO} -function GetSystemInstanceList")| tr -d ',' | awk -F"[ ]" '{ print $12}')
 # Find System Replication Mode
 SRMODE=$(echo -e $(su - ${SIDADM} -c "hdbnsutil  -sr_stateConfiguration | grep -w mode") | awk '{print $2}')
  }



do_or_dont () {

if [ "${UP}" == "GREEN" ]; then
   if [ "${SRMODE}" == "primary" ];then
      echo "This system is acting as a ${SRMODE}."
	  echo "Proceed? y/n"
	  read yn
	  if [ "$yn" == "y" ]; then
	     echo "proceeding"
	  else
        echo "exiting"
		exit 2
      fi		
   fi
else
   echo "System status is not GREEN"
fi   

}

#########################################################################################
################                                                         ################
#############                                                                 ###########
#########                                                                       #########
####                                  MAIN                                           ####
#########                                                                       #########
############                                                                 ############
###############                                                           ###############
#########################################################################################
##
## Start and run functions:
##

is_allowed
check_sap
if [ "${SRMODE}" == "none" ];then
   echo "Systemreplication is not enabled. do the tasks manual"
   exit 2
fi   

case "$1" in
    -c )
        is_alive ;;
    -r )
	    do_or_dont
        remove_ip ;;
	-a )
        add_ip;;	
	-h )
        check_sap;;
	*)
        echo "Usage: -c | -r | -a";	
   
esac

