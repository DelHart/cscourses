#!/usr/bin/env perl

use feature say;
use strict;
use warnings;

use Data::Dumper;
use CSchema;

my $s = CSchema->connect('dbi:SQLite:courses.sqlite')
  || die "could not open database";

calc_regions($s);

# load all of the courses and the prerequisites
# then do leader election to identify components

sub calc_regions {
    my $s = shift;

    # this is a table of all of the ancestors each course has
    my $course_table = {};

    # this is the table of courses to components
    my $component_table = {};

    # get all of the courses
    my @courses = $s->resultset('Course')->all();
    foreach my $c (@courses) {
        my $course = $c->get_column('course');
        my $comp   = $c->get_column('component');
        $component_table->{$course} = $comp;
    }    # foreach course

    # get all the ancestors
    my @ancestors = $s->resultset('Ancestor')->all();

    # now insert these into the ancestry table
    foreach my $a (@ancestors) {
        my $course   = $a->get_column('course');
        my $ancestor = $a->get_column('ancestor');

        # cache the prereq data by course
        $course_table->{$course} = []
          unless ( defined $course_table->{$course} );
        push @{ $course_table->{$course} }, $ancestor;

    }    # foreach ancestor relationship

    my $changes = 0;

    do {
        $changes = 0;

        # foreach course with ancestors
        foreach my $c ( keys(%$course_table) ) {

         # check each ancestor to see if there is a change that needs to be made
            foreach my $a ( @{ $course_table->{$c} } ) {
                if ( $component_table->{$c} != $component_table->{$a} ) {
                    $changes++;
                    if ( $component_table->{$c} < $component_table->{$a} ) {
                        $component_table->{$a} = $component_table->{$c};
                    }
                    else {
                        $component_table->{$c} = $component_table->{$a};
                    }
                }
            }
        }

        say "num changes is $changes";

    } while ( $changes > 0 );

    # now update the courses
    foreach my $c ( keys %$component_table ) {
        my $course = $s->resultset('Course')->find( { 'course' => $c } );
        $course->set_column( 'component', $component_table->{$c} );
        $course->update;
    }

}    # calc_regions

