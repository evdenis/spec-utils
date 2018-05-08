#!/bin/bash

while (( $# > 0 ))
do
   case "$1" in
      --dir)
         dir=$2
         break
         ;;
      *)
         shift
         ;;
   esac
done

if [[ -z "$dir" || ! -r "$dir/module.c" ]]
then
   exit 1
fi

FUNC=$(basename $dir)

OUT=$(frama-c -jessie -jessie-target why3prove -jessie-why3-opt "\ -a split_goal_wp -P alt-ergo" "$dir/module.c" 2>&1)

ERR=$?

OUT=$(echo "$OUT" | grep -Fe $FUNC)
echo "$OUT" | grep -qPie '\b(timeout|invalid)\b'
ERR_INVALID=$?
echo "$OUT" | grep -qPie '\bvalid\b'
ERR_VALID=$?

echo -n 'VERDICT: '
if [[ $ERR -eq 0 && $ERR_INVALID -eq 0 ]]
then
   #echo $OUT
   echo "$FUNC TIMEOUT"
   exit 1
elif [[ $ERR -eq 0 && $ERR_VALID -eq 0 ]]
then
   echo "$FUNC VALID"
else
   echo "$FUNC NOSPEC"
fi

exit $ERR

