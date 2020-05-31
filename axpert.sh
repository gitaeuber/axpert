#!/bin/bash
#
# © Lars Täuber; AGPLv3 http://www.gnu.org/licenses/agpl-3.0.html
#   lars.taeuber@web.de
#
# 2019-12-17	better testing for checksum
# 2019-12-05	simpler and faster - use "raw" mode when used with ser2net
# 2019-11-23	initial version
#

# serial settings: 2400 baud 8N1
#
# use SERVER and PORT if you connect via a ser2net server
SERVER=ser2net
PORT=2000
#DEV="/dev/ttyUSB0"
DEV="/dev/tcp/$SERVER/$PORT"
USE_CRIPPLED_TTY=""

#                8    N       1
# stty -F $DEV cs8 -parenb -cstopb 2400


function axpert_crc16() {
    CRC_TA=($((0x0000)) $((0x1021)) $((0x2042)) $((0x3063)) $((0x4084)) $((0x50a5)) $((0x60c6)) $((0x70e7))
	    $((0x8108)) $((0x9129)) $((0xa14a)) $((0xb16b)) $((0xc18c)) $((0xd1ad)) $((0xe1ce)) $((0xf1ef)))
    STR="$1";
    ((CRC=0));

    for ((LEN=${#1}; LEN != 0; LEN--))
    do
	((PTR=$(printf "0x%X" "'${STR:(-$LEN):1}")));		#"
	((DA=(0xFFFF & CRC)>>12));
	((CRC<<=4));
	((CRC^=${CRC_TA[$((DA^($PTR>>4)))]}));
	((DA=(0xFFFF & CRC)>>12));
	((CRC<<=4));
	((CRC^=${CRC_TA[$((DA^(PTR & 0x0F)))]}));
    done

    ((CRC_L=0xFF & CRC));
    case "$CRC_L" in
	$((0x28)) | $((0x0D)) | $((0x0A)) )
	    ((CRC_L++));
	;;
    esac

    ((CRC_H=0xFF & (CRC>>8)));
    case "$CRC_H" in
	$((0x28)) | $((0x0D)) | $((0x0A)) )
	    ((CRC_H++));
	;;
    esac

    printf '\\x%02X\\x%02X\n' $((CRC_H)) $((CRC_L));
}


function help() {
    echo "usage: $0 [-c] [-u DEV] [-d DEV] CMD [[CMD] ...]"
    echo "       -c: show supported commands"
    echo "       -d: use \"normal\" devices"
    echo "          DEV: device to connect to; e.g. /dev/ttyUSB0 or /dev/tcp/ser2net.de/PORT"
    echo
    echo " $0 sends a command CMD to axpert compatible inverter an prints the answer."
    echo
}


function get_answer_for_cmd() {
    exec 5<>"$DEV" || return 1

    test "QPIGS" = "$1" && \
	echo -e "\nU_GRID F_GRID U_OUT F_OUT VA_OUT P_OUT LOAD% U_BUS U_BATT I_BATT_IN C_BATT T_INV I_PV2BATT U_PV U_BATT_SCC I_BATT_OUT STATUS_BITS1 dU_FAN EEPROM P_PV STATUS_BITS2"

    echo -en "$1\t"
    echo -en "$1$(axpert_crc16 "$1")\r" >&5

    read -u 5 -t 8 -d $'\r' LINE
    RETURN=$?

    if [ "${LINE:0:4}" = "(NAK" ]
    then
	echo "NAK: command unknown to the inverter."
    # test for correct length($LINE)
    elif [ "${LINE:0:4}" = "(ACK" ]
    then
	echo "ACK"
    else
	if [ "$RETURN" -gt 128 ]
	then
	    echo -e "Command timed out. $RETURN: ${#LINE}\t${LINE:0:(${#LINE}-2)}"
	elif [ "${LINE:0:1}${LINE:(-2)}" = "($(echo -en "$(axpert_crc16 "${LINE:0:(${#LINE}-2)}")")" ]
	then
#	    echo "${#LINE}:${LINE:1:(${#LINE}-2)}"
	    echo "${LINE:1:(${#LINE}-3)}"
	else
#	    echo "${LINE:1:(${#LINE}-2)}"
	    echo "${#LINE}:${LINE}"
	fi
    fi
    exec 5>&-
}


# parse device option
if [ $# -ge 1 ]
then
    case "$1" in
	-d)
	    test $# -lt 2 && {
		echo "error parsing device after \"$1\"" >&2
		help
		exit
	    }
	    DEV="$2"
	    shift 2
	    ;;
	"-h"|"-help"|"--help")
	    help
	    exit
	    ;;
    esac
fi


if [ $# -gt 0 ]
then
    while [ $# -gt 0 ]
    do
	get_answer_for_cmd "$1"
	case $? in
	    1)	echo "Error talking to inverter via $DEV" >&2
		exit 1
		;;
	esac
	shift
    done
else
    while read -p "> " -a CMD
    do
	get_answer_for_cmd "$CMD"
	case $? in
	    1)	echo "Error talking to inverter via $DEV" >&2
		exit 1
		;;
	    2)	echo "Command $1 unknown. Please use {-c} to get a list of known commands." >&2
		;;
	esac
    done
fi
