package Configuration;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(
  use_stdlib
  get_files_to_check_repo
  get_include_paths
  add_defines
  add_includes
  recursive_search
  switch_system
);

our %SYSTEM_SWITCH = (
   linux => {
      default_recursive => 1,
      use_stdlib        => 0,
      detect_files      => [
         qw(
           Kconfig
           Makefile
           drivers
           include
           arch
           kernel
           security
           )
      ],
      includes      => "#include <linux/kconfig.h>\n\n",
      defines       => "#define __KERNEL__ 1\n#define MODULE 1\n\n",
      include_paths => [
         qw(
           arch/x86/include
           arch/x86/include/generated
           include
           include/generated
           arch/x86/include/uapi
           arch/x86/include/generated/uapi
           include/uapi
           include/generated/uapi
           )
      ]
   },
   contiki => {
      default_recursive => 0,
      use_stdlib        => 1,
      detect_files      => [
         qw(
           arch
           os
           Makefile.include
           Makefile.identify-target
           )
      ],
      include_paths => [
         qw(
           arch/cpu/native
           arch/platform/native
           os
           os/dev
           os/lib
           os/lib/dbg-io
           os/lib/json
           os/net
           os/net/app-layer/coap
           os/net/app-layer/coap/tinydtls-support
           os/net/app-layer/httpd-ws
           os/net/app-layer/http-socket
           os/net/app-layer/mqtt
           os/net/ipv6
           os/net/ipv6/multicast
           os/net/mac
           os/net/mac/ble
           os/net/mac/csma
           os/net/mac/framer
           os/net/mac/nullmac
           os/net/mac/tsch
           os/net/mac/tsch/sixtop
           os/net/nullnet
           os/net/routing
           os/net/routing/rpl-classic
           os/net/routing/rpl-lite
           os/services/at-master
           os/services/ip64
           os/services/ipso-objects
           os/services/lwm2m
           os/services/orchestra
           os/services/rpl-border-router
           os/services/rpl-border-router/native
           os/services/shell
           os/services/slip-cmd
           os/storage/antelope
           os/storage/cfs
           os/sys
           )
      ]
   }
);

our $SYSTEM = $SYSTEM_SWITCH{linux};

sub switch_system
{
   my ($key) = @_;

   if ($key && exists $SYSTEM_SWITCH{$key}) {
      $SYSTEM = $SYSTEM_SWITCH{$key};
      return 1;
   }

   return 0;
}

sub recursive_search
{
   return $SYSTEM->{default_recursive};
}

sub use_stdlib
{
   return $SYSTEM->{use_stdlib} ? '' : ' -nostdinc ';
}

sub get_files_to_check_repo
{
   return @{$SYSTEM->{detect_files}};
}

sub get_include_paths
{
   return @{$SYSTEM->{include_paths}};
}

sub add_includes
{
   if (exists $SYSTEM->{includes}) {
      $_[0] = $SYSTEM->{includes} . $_[0];
   } else {
      $_[0];
   }
}

sub add_defines
{
   if (exists $SYSTEM->{defines}) {
      $_[0] = $SYSTEM->{defines} . $_[0];
   } else {
      $_[0];
   }
}

1;
