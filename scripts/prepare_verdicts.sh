#!/bin/bash

LOG=${1:-verification.log}

nospec=$(fgrep -e "NOSPEC" "$LOG" | sort)
fail=$(fgrep -e "INSTRUMENT FAIL" "$LOG" | sort)
unproved=$(fgrep -e "UNPROVED" "$LOG" | sort)
partially=$(fgrep -e "PARTIALLY PROVED" "$LOG" | sort)
total=$(grep -e "\bPROVED\b" "$LOG" | fgrep -v "PARTIALLY" | sort)

exit_status=0
log=''
if [[ -n $nospec || -n $fail || -n $unproved ]]
then
	exit_status=1
	log+="$nospec\n"
	log+="$file\n"
	log+="$unproved\n"
fi

log+="$partially\n"
log+="$total"
log=$(echo -e "$log" | grep -v -e '^[[:space:]]*$')
echo "$log"

exit $exit_status

