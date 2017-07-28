#!/bin/bash
# Autor: Julyamnis Marval
# Created Date: 30/03/2016
# Modify Date: 12/08/2016
# Version: 1.6
# Script that manages the internet connection on a raspberryPi 3 (wired, wireless and 3g modem)

####################### Configuration #####################

# environment variable values
TRUE=true
FALSE=false
# conf file path
ARCHIVE=/etc/failover.conf
# logs path
LOG1=/var/log/failover.log
LOG2=/var/log/messages.log
# value of environment variable
INTERNET=$(sed -n 's/.*INTERNET *= *\([^ ]*.*\)/\1/p' < /etc/environment)
# value of curl path
CURL=$(sed -n 's/.*CURL *= *\([^ ]*.*\)/\1/p' < /etc/failover.conf)
# curl execution
TEST_CURL=`curl $CURL -s` >> /var/log/failover.log
# json ok value
RESPONSE_OK="{\"response\":{},\"error\":{\"code\":0,\"msg\":\"Ok\"}}"
# hostname
HOSTNAME=`hostname`
# wget index.html download path
FILE_INDEX="/tmp/index.html"
# 3g default gateway
GSM_GW=10.64.64.64
# enter name of 3G interface
GSM_IF=`ifconfig | grep 'ppp' | awk '{print $1}'`
# enter name of WAN interface
WAN_IF=`ifconfig | grep 'eth' | awk '{print $1}'`
# enter name of WLAN interface
WLAN_IF=`ifconfig | grep 'wlan' | awk '{print $1}'`
# array of priorities
priority=()
# array of phones
phones=()
# getting gateways
default_gw=`route|grep default|awk '{print $8}'`
default=`route|grep default|awk '{print $2}'`



###################### EOF configuration ####################
 
##################### Functions #############################

configuration_file(){

	# this function loads the initial configuration of the script

	j=0
	CONFIGURATION_PRIORITY=$(sed -n 's/.*CONFIGURATION_PRIORITY *= *\([^ ]*.*\)/\1/p' < $ARCHIVE )
	arr=$(echo $CONFIGURATION_PRIORITY | tr "," "\n")
	arr=`echo "$arr" | tr -d ' '`
	for x in $arr; do
		if [[ ! -z "$j" ]];then
			priority[j]=$x
			echo "`date +%F" "%H":"%M":"%S` - Priority $j: ${priority[$j]}" >> $LOG1
			echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Priority $j: ${priority[$j]}" >> $LOG2
		fi	# ! $j
		((j+=1))
	done

	j=0
	PHONE=$(sed -n 's/.*PHONE *= *\([^ ]*.*\)/\1/p' < $ARCHIVE)
	arr=$(echo $PHONE | tr "," "\n")
	arr=`echo "$arr" | tr -d ' '`
	for x in $arr; do
		if [[ ! -z "$j" ]];then
			phones[j]=$x
			echo "`date +%F" "%H":"%M":"%S` - Phone $j: ${phones[$j]}" >> $LOG1
			echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Phone $j: ${phones[$j]}" >> $LOG2
		fi	# ! $j
		((j+=1))
	done

}

ppp_verification(){

	if [[ ! $GSM_IF ]]; then
		
		echo "`date +%F" "%H":"%M":"%S` - No ttyUSB0 mounted. Trying to mount it. " >> $LOG1
		echo "`date +%F" "%H":"%M":"%S` - Failover INFO - No ttyUSB0 mounted. Trying to mount it." >> $LOG2

		./usb_modeswitch &

	done

}

3g_gateway(){

        # this function add default gateway for 3G interface -
        # usually executed when moving internet connection from WAN to 3G interface

		echo "`date +%F" "%H":"%M":"%S` - Moving internet connection to $GSM_IF via gateway: $GSM_GW." >> $LOG1
        echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Moving internet connection to $GSM_IF (3G) via gateway: $GSM_GW." >> $LOG2
        route add default gw $GSM_GW $GSM_IF
        default_gw=$GSM_IF
        default=$GSM_GW

}

wan_gateway(){

	# this function remove default gateway for WAN interface -
        # usually executed when moving internet connection from 3G to WAN interface
 
        echo "`date +%F" "%H":"%M":"%S` - Moving internet connection to $WAN_IF via gateway $WAN_GW." >> $LOG1
        echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Moving internet connection to $WAN_IF via gateway $WAN_GW." >> $LOG2
        route del default gw $default $default_gw
        route add default gw $WAN_GW $WAN_IF
        default_gw=$WAN_IF
        default=$WAN_GW
}

wlan_gateway(){

	# this function remove default gateway for wan interface -
	# usually executed when moving internet connection from WAN to WLAN interface

	echo "`date +%F" "%H":"%M":"%S` - Moving internet connection to $WLAN_IF via gateway $WLAN_GW." >> $LOG1
	echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Moving internet connection to $WLAN_IF via gateway $WLAN_GW." >> $LOG2
        route del default gw $default $default_gw
        route add default gw $WLAN_GW $WLAN_IF
        default_gw=$WLAN_IF
        default=$WLAN_GW
}

gettingWlan(){

	# this function obtaing the wireless usb information
	# usually executed when moving internet connection from WAN or 3G to WLAN

	if [[ $WLAN_IF ]]; then
		echo "`date +%F" "%H":"%M":"%S` - Wireless USB detected." >> $LOG1
		echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Wireless USB detected." >> $LOG2
		for i in $( ifconfig | grep 'wlan' | awk '{print $1}' ); do
			connect=`iwconfig "$i" | grep "ESSID" | awk '{print $4}'`
			if [[ $connect != "ESSID:off/any" ]]; then
				echo "`date +%F" "%H":"%M":"%S` - Connected to: $connect" >> $LOG1
				echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Connected to: $connect" >> $LOG2
				is=true
				break
			fi	# connect != "ESSID:off/any"
		done
	else
		is=false
		echo "`date +%F" "%H":"%M":"%S` - No wireless USB detected." >> $LOG1
		echo "`date +%F" "%H":"%M":"%S` - Failover INFO - No wireless USB detected." >> $LOG2
	fi 			# wlan_if

}

wlan_connect(){

	# This function check if there's a wlan interface to connect and
	# change de the default gateway so the connection is on the wlan.

	gettingWlan

	if [[ $is="true" ]]; then

		# If there's a wlan interface then change de default gateway and
		# check the connection on it.

		#wget www.google.com.ve -P /tmp/

		#if [[ -f $FILE_INDEX ]];then
		if [[ "$TEST_CURL" == "$RESPONSE_OK" ]]; then
			#  if WLAN interface is up and running.

			echo "`date +%F" "%H":"%M":"%S` - WLAN interface ($WLAN_IF) connected." >> $LOG1
			echo "`date +%F" "%H":"%M":"%S` - Failover INFO - WLAN interface ($WLAN_IF) connected." >> $LOG2
			sed -i "s#$INTERNET#$TRUE#g" /etc/environment
			echo "`date +%F" "%H":"%M":"%S` - INTERNET = TRUE on /etc/environment." >> $LOG1
			echo "`date +%F" "%H":"%M":"%S` - INTERNET = TRUE on /etc/environment." >> $LOG2
			/sbin/iptables -P FORWARD ACCEPT
			/sbin/iptables --table nat -A POSTROUTING -o $WLAN_IF -j MASQUERADE
			#rm $FILE_INDEX
		else
			# if WLAN interface is down.

			echo "`date +%F" "%H":"%M":"%S` - WLAN inteface ($WLAN_IF) is down or not configured." >> $LOG1
			echo "`date +%F" "%H":"%M":"%S` - Failover INFO - WLAN inteface ($WLAN_IF) is down or not configured." >> $LOG2
			wl_connect=0
		fi		# if file_index
	fi			# ! $i
}

3g_connects(){

	# This function check if there's a modem 3g to connect and
	# change the default gateway so the connection is established on
	# the 3g modem.
	
	wvdial &
	
	if [[ $GSM_IF ]];then

		# if there's a modem connected.

		echo "`date +%F" "%H":"%M":"%S` - 3g Modem: $GSM_IF." >> $LOG1
		echo "`date +%F" "%H":"%M":"%S` - Failover INFO - 3g Modem: $GSM_IF." >> $LOG2

		#wget www.google.com.ve -P /tmp/

		#if [[ -f $FILE_INDEX ]];then
		if [[ "$TEST_CURL" == "$RESPONSE_OK" ]]; then
			# if there's ping from 3g modem and there's a modem installed, then connect.

			echo "`date +%F" "%H":"%M":"%S` - Established connection on 3G modem ($GSM_IF)." >> $LOG1
			echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Established connection on 3G modem ($GSM_IF)." >> $LOG2
			sed -i "s#$INTERNET#$TRUE#g" /etc/environment
			echo "`date +%F" "%H":"%M":"%S` - INTERNET = TRUE on /etc/environment." >> $LOG1
			echo "`date +%F" "%H":"%M":"%S` - INTERNET = TRUE on /etc/environment." >> $LOG2
			/sbin/iptables -P FORWARD ACCEPT
			/sbin/iptables --table nat -A POSTROUTING -o $GSM_IF -j MASQUERADE
			#rm $FILE_INDEX
		fi	# file_index
	else
		echo "`date +%F" "%H":"%M":"%S` - There's not 3g modem to connect." >> $LOG1
		echo "`date +%F" "%H":"%M":"%S` - Failover INFO - There's not 3g modem to connect." >> $LOG2
		gsm_connect=0
	fi		# $gsm_if
}

wan_connect(){

	# This function check if there's a wan interface to connect and
	# change de the default gateway so the connection is on wan.

	wan_chk=`ifconfig |grep "$WAN_IF"`

	if [[ $wan_chk ]];then

		# if there's a wan interface
		echo "`date +%F" "%H":"%M":"%S` - WAN interface: $wan_chk." >> $LOG1
		echo "`date +%F" "%H":"%M":"%S` - Failover INFO - WAN interface: $wan_chk." >> $LOG2

		#wget www.google.com.ve -P /tmp/

		#if [[ -f $FILE_INDEX ]];then
		if [[ "$TEST_CURL" == "$RESPONSE_OK" ]]; then
			# if there is reply from PING_HOST on WAN interface
			echo "`date +%F" "%H":"%M":"%S` - There is connection on WAN interface ($WAN_IF). " >> $LOG1
			echo "`date +%F" "%H":"%M":"%S` - Failover INFO - There is connection on WAN interface ($WAN_IF). " >> $LOG2
			sed -i "s#$INTERNET#$TRUE#g" /etc/environment
			echo "`date +%F" "%H":"%M":"%S` - INTERNET = TRUE on /etc/environment." >> $LOG1
			echo "`date +%F" "%H":"%M":"%S` - INTERNET = TRUE on /etc/environment." >> $LOG2
			/sbin/iptables -P FORWARD ACCEPT
			/sbin/iptables --table nat -A POSTROUTING -o $WAN_IF -j MASQUERADE
			#rm $FILE_INDEX
		else
			# case info: WAN interface down or not configured - trying to up interface and exit
			echo "`date +%F" "%H":"%M":"%S` - WAN inteface ($WAN_IF) is down or not configured." >> $LOG1
			echo "`date +%F" "%H":"%M":"%S` - Failover INFO - WAN inteface ($WAN_IF) is down or not configured." >> $LOG2
			w_connect=0
		fi		# if file_index
	fi			# wan_chk
}

######################### EOF functions ########################


######################## Configuration File ####################

configuration_file
ppp_verification
cd /etc/failover/

# Assigning initial configurations for future use

priority1=${priority[0]}
priority2=${priority[1]}
priority3=${priority[2]}


###############################################################


if [[ $priority1 = "eth" ]]; then

	echo "`date +%F" "%H":"%M":"%S` - Priority 1 is $WAN_IF ." >> $LOG1
	echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Priority 1 is $WAN_IF ." >> $LOG2

	if [[ $default_gw = $WAN_IF ]];then
		FIRST_GW=`route|grep $WAN_IF|grep "UG"|awk {'print $2}'`
		one=$FIRST_GW
		WAN_GW=`echo $one | sed 's/.$/1/g'`
	else
		FIRST_GW=`route|grep $WAN_IF|awk {'print $1}'`
		one=$FIRST_GW
		WAN_GW=`echo $one | sed 's/.$/1/g'`
	fi	# default_gw

	wan_gateway
	wan_connect

	if [[ $w_connect = "0" ]]; then

		if [[ $priority2 = "wlan" ]]; then

			if [[ $default_gw = $WLAN_IF ]];then
				SECOND_GW=`route|grep $WLAN_IF|grep "UG"|awk {'print $2}'`
				two=$SECOND_GW
				WLAN_GW=`echo $two | sed 's/.$/1/g'`
			else
				SECOND_GW=`route|grep $WLAN_IF|awk {'print $1}'`
				two=$SECOND_GW
				WLAN_GW=`echo $two | sed 's/.$/1/g'`
			fi	# default_gw

			echo "`date +%F" "%H":"%M":"%S` - Priority 2 is $WLAN_IF ." >> $LOG1
			echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Priority 2 is $WLAN_IF ." >> $LOG2

			wlan_gateway
			wlan_connect

			if [[ $wl_connect = "0" ]]; then

				# if wlan up fails then connect to 3g.

				echo "`date +%F" "%H":"%M":"%S` - Connecting to $priority3." >> $LOG1
				echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Connecting to $priority3." >> $LOG2

				3g_gateway
				3g_connects

				if [[ $gsm_connect = "0" ]];then
					echo "`date +%F" "%H":"%M":"%S` - All connections down! Sending a SMS." >> /$LOG1
					echo "`date +%F" "%H":"%M":"%S` - Failover INFO - All connections down! Sending a SMS.">> $LOG2
					sed -i "s#$INTERNET#$FALSE#g" /etc/environment
					echo "`date +%F" "%H":"%M":"%S` - INTERNET = FALSE on /etc/environment." >> /$LOG1
					echo "`date +%F" "%H":"%M":"%S` - INTERNET = FALSE on /etc/environment." >> $LOG2

					poff
					cont=0
					until [ $cont -gt 2 ];
					do
						gammu sendsms text  ${phones[$cont]} -text "All connections down in $HOSTNAME!" >> $LOG1
						let cont=cont+1 
					done
					pon
				fi	# w_connect = 0
			fi		# wl_connect
		fi			# priority2 == wlan_if

		if [[ $priority2 = "ppp" ]]; then

			if [[ $default_gw = $GSM_IF ]];then
				THIRD_GW=`route|grep $WLAN_IF|awk {'print $1'}`
				three=$THIRD_GW
				WLAN_GW=`echo $three | sed 's/.$/1/g'`
			else
				THIRD_GW=`route|grep $WLAN_IF|awk {'print $1'}`
				three=$THIRD_GW
				WLAN_GW=`echo $three | sed 's/.$/1/g'`
			fi	# defalt_gw

			echo "`date +%F" "%H":"%M":"%S` - Priority 2 is $GSM_IF ." >> $LOG1
			echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Priority 2 is $GSM_IF .">> $LOG2

			3g_gateway
			3g_connects

			if [[ $gsm_connect = "0" ]]; then

				# if there's not ping from 3g modem, then connect to wlan.

				echo "`date +%F" "%H":"%M":"%S` - Connecting to $priority3.">> $LOG1
				echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Connecting to $priority3." >> $LOG2

				wlan_gateway
				wlan_connect

				if [[ $wl_connect = "0" ]]; then
					echo "`date +%F" "%H":"%M":"%S` - All connections down! Sending a SMS." >> $LOG1
					echo "`date +%F" "%H":"%M":"%S` - Failover INFO - All connections down! Sending a SMS." >> $LOG2
					sed -i "s#$INTERNET#$FALSE#g" /etc/environment
					echo "`date +%F" "%H":"%M":"%S` - INTERNET = FALSE on /etc/environment." >> $LOG1
					echo "`date +%F" "%H":"%M":"%S` - INTERNET = FALSE on /etc/environment." >> $LOG2

					poff
					cont=0
					until [ $cont -gt 2 ];
					do
						gammu sendsms text  ${phones[$cont]} -text "All connections down in $HOSTNAME!" >> $LOG1
						let cont=cont+1 
					done
					pon
					
				fi	# wl_connect
			fi		# gsm_connect
		fi			# priority2 == gsm_if
	fi				# connect 0
fi					# priority 1 wan

if [[ $priority1 = "wlan" ]]; then

	echo "`date +%F" "%H":"%M":"%S` - Priority 1 is $WLAN_IF ." >> $LOG1
	echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Priority 1 is $WLAN_IF ." >> $LOG2
	if [[ $default_gw = $WLAN_IF ]];then
		FIRST_GW=`route|grep $WLAN_IF|grep "UG"|awk {'print $2}'`
		one=$FIRST_GW
		WLAN_GW=`echo $one | sed 's/.$/1/g'`
	else
		FIRST_GW=`route|grep $WLAN_IF|awk {'print $1}'`
		one=$FIRST_GW
		WLAN_GW=`echo $one | sed 's/.$/1/g'`
	fi	# default_gw

	wlan_gateway
	wlan_connect

	if [[ $wl_connect = "0" ]]; then

		if [[ $priority2 = "eth" ]]; then

			echo "`date +%F" "%H":"%M":"%S` - Priority 2 is $WAN_IF." >> $LOG1
			echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Priority 2 is $WAN_IF." >> $LOG2

			if [[ $default_gw = $WAN_IF ]];then
				SECOND_GW=`route|grep $WAN_IF|grep "UG"|awk {'print $2}'`
				two=$SECOND_GW
				WAN_GW=`echo $two | sed 's/.$/1/g'`
			else
				SECOND_GW=`route|grep $WAN_IF|awk {'print $1}'`
				two=$SECOND_GW
				WAN_GW=`echo $two | sed 's/.$/1/g'`
				echo $WAN_GW
			fi	# default_gw

			wan_gateway
			wan_connect

			if [[ $w_connect = "0" ]]; then

				# if there's not connection with WAN interface
				# then try to connect to 3g interface.

				echo "`date +%F" "%H":"%M":"%S` - Connecting to $priority3." >> $LOG1
				echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Connecting to $priority3." >> $LOG2

				3g_gateway
				3g_connects

				if [[ $gsm_connect = "0" ]]; then
					echo "`date +%F" "%H":"%M":"%S` - All connections down! Sending a SMS." >> $LOG1
					echo "`date +%F" "%H":"%M":"%S` - Failover INFO - All connections down! Sending a SMS." >> $LOG2
					sed -i "s#$INTERNET#$FALSE#g" /etc/environment
					echo "`date +%F" "%H":"%M":"%S` - INTERNET = FALSE on /etc/environment." >> $LOG1
					echo "`date +%F" "%H":"%M":"%S` - INTERNET = FALSE on /etc/environment." >> $LOG2

					poff
					cont=0
					until [ $cont -gt 2 ];
					do
						gammu sendsms text  ${phones[$cont]} -text "All connections down in $HOSTNAME!" >> $LOG1
						let cont=cont+1 
					done
					pon
				fi	# gsm_connect = 0
			fi		# connect0
		fi			# priority2 = wan

		if [[ $priority2 = "ppp" ]]; then

			if [[ $default_gw = $GSM_IF ]];then
				THIRD_GW=`route|grep $WAN_IF|awk {'print $1'}`
				three=$THIRD_GW
				WAN_GW=`echo $three | sed 's/.$/1/g'`
			else
				THIRD_GW=`route|grep $WAN_IF|awk {'print $1'}`
				three=$THIRD_GW
				WAN_GW=`echo $three | sed 's/.$/1/g'`
			fi	# default_gw

			echo "`date +%F" "%H":"%M":"%S` - Priority 2 is $GSM_IF ." >> $LOG1
			echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Priority 2 is $GSM_IF ." >> $LOG2
			3g_gateway
			3g_connects

			if [[ $gsm_connect = "0" ]]; then

				# if there's not connection with gsm interface
				# then try to connect to wan interface.

				echo "`date +%F" "%H":"%M":"%S` - Connecting to $priority3." >> $LOG1
				echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Connecting to $priority3." >> $LOG2

				wan_gateway
				wan_connect
				if [[ $w_connect = "0" ]];then
					echo "`date +%F" "%H":"%M":"%S` - All connections down! Sending a SMS." >> $LOG1
					echo "`date +%F" "%H":"%M":"%S` - Failover INFO - All connections down! Sending a SMS." >> $LOG2
					sed -i "s#$INTERNET#$FALSE#g" /etc/environment
					echo "`date +%F" "%H":"%M":"%S` - INTERNET = FALSE on /etc/environment." >> $LOG1
					echo "`date +%F" "%H":"%M":"%S` - INTERNET = FALSE on /etc/environment." >> $LOG2
					
					poff
					cont=0
					until [ $cont -gt 2 ];
					do
						gammu sendsms text  ${phones[$cont]} -text "All connections down in $HOSTNAME!" >> $LOG1
						let cont=cont+1 
					done
					pon
				fi	# w_connect = 0
			fi		# gsm_connect = 0
		fi			# priority2
	fi				# connect = 0
fi					# priority 1 wlan

if [[ $priority1 = "ppp" ]]; then

	echo "`date +%F" "%H":"%M":"%S` - Priority 1 is $GSM_IF ." >> $LOG1
	echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Priority 1 is $GSM_IF ." >> $LOG2

	3g_gateway
	3g_connects

	if [[ $gsm_connect = "0" ]]; then

		# if there's not a gsm interface running
		# then connect to another interface.

		if [[ $priority2 = "eth" ]]; then

			if [[ $default_gw = $WAN_IF ]];then
				SECOND_GW=`route|grep $WAN_IF|grep "UG"|awk {'print $2}'`
				two=$SECOND_GW
				WAN_GW=`echo $two | sed 's/.$/1/g'`
				THIRD_GW=`route|grep $WLAN_IF|awk {'print $1'}`
				three=$THIRD_GW
				WLAN_GW=`echo $three | sed 's/.$/1/g'`
			else
				SECOND_GW=`route|grep $WAN_IF|awk {'print $1}'`
				two=$SECOND_GW
				WAN_GW=`echo $two | sed 's/.$/1/g'`
				THIRD_GW=`route|grep $WLAN_IF|awk {'print $1'}`
				three=$THIRD_GW
				WLAN_GW=`echo $three | sed 's/.$/1/g'`
			fi	# default_gw
			echo "`date +%F" "%H":"%M":"%S` - Priority 2 is $WAN_IF ." >> $LOG1
			echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Priority 2 is $WAN_IF ." >> $LOG2

			wan_gateway
			wan_connect

			if [[ $w_connect = "0" ]]; then

				# if there's not connection with WAN interface
				# then try to connect to wlan interface.

				echo "`date +%F" "%H":"%M":"%S` - Connecting to $priority3." >> $LOG1
				echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Connecting to $priority3." >> $LOG2

				wlan_gateway
				wlan_connect

				if [[ $wl_connect = "0" ]];then
					echo "`date +%F" "%H":"%M":"%S` - All connections down! Sending a SMS." >> $LOG1
					echo "`date +%F" "%H":"%M":"%S` - Failover INFO - All connections down! Sending a SMS." >> $LOG2
					sed -i "s#$INTERNET#$FALSE#g" /etc/environment
					echo "`date +%F" "%H":"%M":"%S` - INTERNET = FALSE on /etc/environment." >> $LOG1
					echo "`date +%F" "%H":"%M":"%S` - INTERNET = FALSE on /etc/environment." >> $LOG2

					poff
					cont=0
					until [ $cont -gt 2 ];
					do
						gammu sendsms text  ${phones[$cont]} -text "All connections down in $HOSTNAME!" >> $LOG1
						let cont=cont+1 
					done
					pon
				fi	# wl_connect = 0
			fi		# w_connect = 0
		fi			# priority2 = wan
		if [[ $priority2 = "wlan" ]]; then

			if [[ $default_gw = $WLAN_IF ]];then
				SECOND_GW=`route|grep $WLAN_IF|grep "UG"|awk {'print $2}'`
				two=$SECOND_GW
				WLAN_GW=`echo $two | sed 's/.$/1/g'`
				THIRD_GW=`route|grep $WAN_IF|awk {'print $1'}`
				three=$THIRD_GW
				WAN_GW=`echo $three | sed 's/.$/1/g'`
			else
				SECOND_GW=`route|grep $WLAN_IF|awk {'print $1}'`
				two=$SECOND_GW
				WLAN_GW=`echo $two | sed 's/.$/1/g'`
				THIRD_GW=`route|grep $WAN_IF|awk {'print $1'}`
				three=$THIRD_GW
				WAN_GW=`echo $three | sed 's/.$/1/g'`
			fi	# default_gw
			echo "`date +%F" "%H":"%M":"%S` - Priority 2 is $WLAN_IF ." >> $LOG1
			echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Priority 2 is $WLAN_IF ." >> $LOG2

			wlan_gateway
			wlan_connect

			if [[ $wl_connect = "0" ]]; then

				# if wlan up fails.

				echo "`date +%F" "%H":"%M":"%S` - Connecting to $priority3." >> $LOG1
				echo "`date +%F" "%H":"%M":"%S` - Failover INFO - Connecting to $priority3." >> $LOG2

				wan_gateway
				wan_connect

				if [[ $w_connect = "0" ]];then
					echo "`date +%F" "%H":"%M":"%S` - All connections down! Sending a SMS." >> $LOG1
					echo "`date +%F" "%H":"%M":"%S` - Failover INFO - All connections down! Sending a SMS." >> $LOG2
					sed -i "s#$INTERNET#$FALSE#g" /etc/environment
					echo "`date +%F" "%H":"%M":"%S` - INTERNET = FALSE on /etc/environment." >> $LOG1
					echo "`date +%F" "%H":"%M":"%S` - INTERNET = FALSE on /etc/environment." >> $LOG2
					
					poff
					cont=0
					until [ $cont -gt 2 ];
					do
						gammu sendsms text  ${phones[$cont]} -text "All connections down in $HOSTNAME!" >> $LOG1
						let cont=cont+1 
					done
					pon
				fi	# w_connect = 0
			fi		# wl_onnect
		fi 			# priority2 = wlan
	fi				# gsm_connect = 0
fi					# priority 1 gsm
