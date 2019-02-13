#!/bin/bash

while (( $# > 0 ))
do
   case "$1" in
      --file)
         file=$2
         break
         ;;
      *)
         shift
         ;;
   esac
done

if [[ -z "$file" || ! -r "$file" ]]
then
   exit 1
fi

frama-c -jessie -jessie-target why3typecheck "$file"
