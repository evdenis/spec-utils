#!/bin/bash -x

#KERNEL_RELEASE=$(uname -r)
#KERNEL_BUILD=/lib/modules/$KERNEL_RELEASE/build
#CURRENT_KERNEL=$KERNEL_BUILD

KERNEL_SOURCES=/home/work/workspace/work/minix/linux-4.8.10
CURRENT_KERNEL=$KERNEL_SOURCES

export CURRENT_KERNEL

modules=(
fs/9p/
fs/minix/
fs/sysfs/
fs/debugfs/
fs/ramfs/

security/yama/
security/apparmor/
security/selinux/

fs/isofs/
fs/gfs2/
fs/ext2/
)
#fs/btrfs/
#fs/f2fs/
#fs/ext2/
#security/tomoyo/

for i in "${modules[@]}"
do
   file=$(basename $i).c
   if [[ ! -f $file ]]
   then
      dismember --module $KERNEL_SOURCES/$i --asmodule -o $file
   fi
done

if [[ ! -f vfat.c ]]
then
   dismember --module $KERNEL_SOURCES/fs/fat/ --mname vfat --asmodule -o vfat.c
fi
if [[ ! -f fat.c ]]
then
   dismember --module $KERNEL_SOURCES/fs/fat/ --mname fat --asmodule -o fat.c
fi
if [[ ! -f msdos.c ]]
then
   dismember --module $KERNEL_SOURCES/fs/fat/ --mname msdos --asmodule -o msdos.c
fi


#for i in *.c
#do
#   gcc -w -c $i
#done


