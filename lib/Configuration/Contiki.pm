package Configuration::Contiki;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(
   use_stdlib
   get_files_to_check_repo
   get_include_paths
   add_defines
   add_includes
);

sub use_stdlib
{
   '';
}

sub get_files_to_check_repo
{
   return qw(arch os Makefile.include Makefile.identify-target);
}

sub get_include_paths
{
   return qw(
      arch/cpu/native
      arch/cpu/native/dev
      arch/cpu/native/net
      arch/platform/native
      arch/platform/native/dev
      os
      os/dev
      os/net
      os/net/ipv6
      os/net/ipv6/multicast
      os/net/routing
      os/net/routing/nullrouting
      os/net/routing/rpl-classic
      os/net/routing/rpl-lite
      os/net/security
      os/net/security/tinydtls
      os/net/security/tinydtls/aes
      os/net/security/tinydtls/contiki-support
      os/net/security/tinydtls/sha2
      os/net/security/tinydtls/posix
      os/net/security/tinydtls/posix/lib
      os/net/security/tinydtls/ecc
      os/net/app-layer
      os/net/app-layer/httpd-ws
      os/net/app-layer/mqtt
      os/net/app-layer/coap
      os/net/app-layer/coap/tinydtls-support
      os/net/app-layer/http-socket
      os/net/nullnet
      os/net/mac
      os/net/mac/nullmac
      os/net/mac/csma
      os/net/mac/ble
      os/net/mac/framer
      os/net/mac/tsch
      os/net/mac/tsch/sixtop
      os/lib
      os/lib/strncasecmp
      os/lib/json
      os/lib/fs
      os/lib/fs/fat
      os/lib/fs/fat/option
      os/lib/fs/fat/option/unicode
      os/lib/newlib
      os/lib/dbg-io
      os/sys
      os/services
      os/services/at-master
      os/services/rpl-border-router
      os/services/rpl-border-router/native
      os/services/rpl-border-router/embedded
      os/services/ipso-objects
      os/services/slip-cmd
      os/services/orchestra
      os/services/tsch-cs
      os/services/lwm2m
      os/services/ip64
      os/services/shell
      os/services/deployment
      os/services/simple-energest
      os/storage
      os/storage/cfs
      os/storage/antelope
   );
}

sub add_includes
{
   $_[0]
}

sub add_defines
{
   $_[0]
}

1;
