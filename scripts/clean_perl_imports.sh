#!/bin/bash

for i in `find . -type f -name *.pm`;
do
	use=$(grep -Poe '^use\h+[^(]+\(\K[^)]+' $i)
	for u in $use
	do
		u=`echo $u | tr -d ':%$@'`
		if [[ $u == 'import' || $u == 'RE' || $u == 'config' || $u == 'no_getopt_compat' || $u == 'permute' || $u == 'pass_through' || $u == 'gnu_compat' ]]
		then
			continue
		fi
		if ! grep -Pv '^use\b' $i | grep -qP "\b$u\b"
		then
			echo "No $u in $i"
		fi
	done
done
