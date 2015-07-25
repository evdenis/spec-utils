package App::Dismember::Plugin::Include;

use warnings;
use strict;

use Pod::Usage;
use Pod::Find qw(pod_where);
use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);
use Kernel::Module::Graph;
use File::Basename;
use File::Spec::Functions qw(catfile);
use File::Copy;
use Cwd qw(abs_path);

=encoding utf8

=pod

=head1 Plugin::Include

Plugin::Include - плагин для добавления директивы #include <file.h> в выводимые файлы

=head1 OPTIONS

=over 8

=item B<--plugin-include-file string>

В string содержится указание на то, в какой файл добавлять директиву #include и путь до самого файла. string имеет формат 'file^path', где file - это kernel_h(1), external_h(2), module_h(3), module_c(4), а path - это путь до подключаемого файла. Плагин копирует файл из path в директорию к остальным файлам и дописывает '#include "$(basename path)"' в файл area.

=item B<--plugin-include-link>

Изменяет поведение опции plugin-include-file. Вместо копирования подключаемого файла происходит создания симлинка на него.

=item B<--plugin-include-help>

Выводит полное описание плагина.

=back

=cut


sub process_options
{
   my ($self, $config) = @_;
   my @include;
   my $help = 0;
   my $link = 1;

   GetOptions(
      'plugin-include-file=s' => \@include,
      'plugin-include-link!'  => \$link,
      'plugin-include-help'   => \$help,
   ) or die("Error in command line arguments\n");

   my $input = pod_where({-inc => 1}, __PACKAGE__);
   pod2usage({ -input   => $input,
               -verbose => 2,
               -exitval => 0 })
       if $help;

   pod2usage({ -input => $input,
               -msg => "Option --plugin-include-file should be provided.\n",
               -exitval => 1 })
      unless @include;

   my %include;
   foreach (@include) {
      chomp;
      if (m/\A([a-zA-Z_]\w+|\d)\^(.*)\Z/) {
         my ($area, $path) = ($1, $2);
         if ($area =~ m/\A\d\Z/) {
            if ($area > 0 && $area < @Kernel::Module::Graph::out_order + 1) {
               $area = $Kernel::Module::Graph::out_order[$area - 1]
            } else {
               die "There is no such area $area\n"
            }
         } elsif (!exists $Kernel::Module::Graph::out_file{$area}) {
            die "There is no such area $area\n"
         }
         unless (-r $path) {
            die "Can't read file $path\n"
         }

         push @{ $include{$area} }, $path
      } else {
         die "Can't parse include id '$_'\n"
      }
   }

   $config->{'include'} = \%include;

   bless { include => \%include, base_dir => $config->{output_dir}, link => $link }, $self
}

sub level
{
   raw_data => 90
}

sub action
{
   my ($self, $opts) = @_;

   return undef
      unless exists $opts->{output} && exists $opts->{output_dir};

   foreach my $area (keys %{$self->{include}}) {
      foreach (@{$self->{include}{$area}}) {
         my $include = basename $_;
         my $old = abs_path $_;
         my $new = catfile($opts->{output_dir}, $include);
         if ($self->{link}) {
            symlink $old, $new;
            print "plugin: include: link $old -> $new\n";
         } else {
            copy($old, $new);
            print "plugin: include: copy $old -> $new\n";
         }

         $opts->{'output'}{$area} = qq(#include "$include"\n\n) .
                                 $opts->{'output'}{$area};
      }
   }

   undef
}


1;
