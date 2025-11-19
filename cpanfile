requires 'perl', '5.22.0';

requires 'Clone';
requires 'Color::Library';
requires 'File::Modified';
requires 'File::Slurp';
requires 'File::Which';
requires 'Graph';
requires 'Graph::Directed';
requires 'Graph::Reader::Dot';
requires 'Graph::Writer::Dot';
requires 'Hash::Ordered';
requires 'IO::Interactive';
requires 'List::MoreUtils';
requires 'List::Util', '1.41';
requires 'Module::Loader';
requires 'Moose';
requires 'Moose::Role';
requires 'Moose::Util::TypeConstraints';
requires 'Pod::Find';
requires 'Try::Tiny';
requires 'YAML';
requires 'lib::abs';
requires 'namespace::autoclean';
requires 'utf8::all';

feature 'merge', 'Move Specs Between Sources Verions' => sub {
  requires 'Algorithm::Diff';
  requires 'Term::Clui';
};

feature 'report', 'Reports Generation' => sub {
  requires 'Text::ANSITable';
  requires 'Class::CSV';
  requires 'Excel::Writer::XLSX';
  requires 'XML::Simple';
  requires 'Term::ProgressBar';
};

feature 'web', 'Web CallGraph Support' => sub {
  requires 'DBI';
  requires 'DBD::SQLite';
  requires 'File::Spec::Functions';
  requires 'Plack::Request';
  requires 'Plack::Builder';
  requires 'Plack::Util';
  requires 'Plack::MIME';
  requires 'HTTP::Date';
  requires 'Starman';
  requires 'JSON';
};

on 'develop' => sub {
  requires 'Smart::Comments';
  requires 'DDP';
  recommends 'Devel::NYTProf';
  recommends 'Smart::Comments';
  suggests 'Devel::Cover::Report::Coveralls';
  suggests 'Devel::Cover::Report::Kritika';
};
