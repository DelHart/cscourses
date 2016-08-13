#!/usr/bin/env perl

use strict;
use warnings;

use DBIx::Class::Schema::Loader qw/ make_schema_at /;
  make_schema_at(
      'CSchema',
      { debug => 1,
        dump_directory => '.',
      },
      [ 'dbi:SQLite:courses.sqlite']
  );

__END__
