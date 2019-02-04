package Configuration::Linux;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(
   get_include_paths
   add_defines
   add_includes
);

sub get_include_paths
{
   return qw(
      arch/x86/include/
      arch/x86/include/generated/
      include/
      include/generated/
      arch/x86/include/uapi/
      arch/x86/include/generated/uapi/
      include/uapi/
      include/generated/uapi/
   );
}

sub add_includes
{
   $_[0] = "#include <linux/kconfig.h>\n\n" . $_[0];
}

sub add_defines
{
   $_[0] = "#define __KERNEL__ 1\n#define MODULE 1\n\n" . $_[0];
}

1;
