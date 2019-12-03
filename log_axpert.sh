#!/bin/bash
#
#
# © Lars Täuber; AGPLv3 http://www.gnu.org/licenses/agpl-3.0.html
#   lars.taeuber@web.de
#
# 2019-12-04	log Device Mode too
# 2019-11-30	small optimizations
# 2019-11-23	initial version
#

# serial settings: 2400 baud 8N1
#
# use SERVER and PORT if you connect via a ser2net server
SERVER="ser2net"
PORT=3000
#DEV="/dev/ttyUSB0"
DEV="/dev/tcp/$SERVER/$PORT"
LOGFILE="/srv/inverter/$(date +%Y-%m)-1.log"
TRIES=2

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
}	# axpert_crc16()

test -e "$LOGFILE" || \
    echo "%Y%m%d%H%M%S U_GRID F_GRID U_OUT F_OUT VA_OUT P_OUT LOAD% U_BUS U_BATT I_BATT_IN C_BATT T_INV I_PV2BATT U_PV U_BATT_SCC I_BATT_OUT STATUS_BITS1 dU_FAN EEPROM P_PV STATUS_BITS2 MODUS" >> "$LOGFILE";

let I=10;
while ! exec 5<>"$DEV"
do
    if [ $I -le 0 ]
    then
	echo "can't contact axpert inverter" >&2
	exit 2
    fi
    let I--;
    sleep 1;
done

function read_axpert() {
    ## empty input buffer
    read -n 30 -t 1 -u 5

    echo -en "$1$(axpert_crc16 "$1")\r" >&5

    if ! read -u 5 -t 2 -d '\r' LINE
    then
	# test for minimum length($LINE), start char "(" and CRC
	if [ "${#LINE}" -lt 4 ]
	then
	    return 1
	elif [ "${LINE:0:1}${LINE:(-3)}" != "($(echo -en "$(axpert_crc16 "${LINE:0:(${#LINE}-3)}")\r")" ]
	then
	    return 1
	fi
    fi
    echo "${LINE:1:(${#LINE}-4)}"
}

RESULT=""

for CMD in QPIGS QMOD
do
    # try multiple times
    for ((I=0; I<TRIES; I++))
    do
	if RESULT="$RESULT $(read_axpert $CMD)"
	then
	    break;
	fi
    done
done

if [ $I -ne $TRIES ]
then
    echo "$(date +%Y%m%d%H%M%S)$RESULT" >> "$LOGFILE";
else
    echo "couldn't read correct line from device" >&2
    exit 1
fi
