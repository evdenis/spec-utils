#!/bin/bash

while (( $# > 0 ))
do
   case "$1" in
      --dir)
         dir=$2
         shift
         ;;
      --file)
         file=$2
         shift
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

gcc -c -w "$file"
