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

frama-c -jessie -jessie-target why3typecheck "$dir/module.c"
