#!/bin/bash

for i in minix fat 9p sysfs ramfs debugfs
do
   ./bin/dismember                                       \
      --config config/dismember-compile-test.conf.sample \
      --all --module                                     \
      $CURRENT_KERNEL/fs/$i                              &&
   mv ./result ./result_$i
done
