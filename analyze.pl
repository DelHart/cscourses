#!/usr/bin/env perl

use feature say;
use strict;
use warnings;

use Data::Dumper;
use CSchema;

my $s = CSchema->connect('dbi:SQLite:courses.sqlite')
  || die "could not open database";

calc_depth ($s);

#calc_ancestors($s);

# calculate the depth of each course
# courses with no prerequisites are depth 0
# a course with prerequisites has depth + 1 of the max of its prerequisites
sub calc_depth {

    my $s = shift;    # get the schema

    my @current;      # the list of courses currently being worked on
    my @future;       # the list of courses to work on next

    #@current = $s->resultset('Course')->all();
    @current = $s->resultset('Course')->search( { 'school' => 1 } );
    while ( $#current > -1 ) {

        say $#current . " courses left to process";

        while ( $#current > -1 ) {
            my $course = shift @current;
            my $cid    = $course->get_column('id');

            say "course " . $course->get_column('course') . " $cid";
            my @prereqs = $course->prereqs();

            # base case of no prereqs
            if ( $#prereqs == -1 ) {
                $course->set_column( 'min_depth', 0 );
                $course->set_column( 'max_depth', 0 );
                $course->update;
            }
            else {
                # calculate the max depth of all prereqs

                my ( $min_depth, $max_depth );
                my ( $min_opt,   $max_opt );

                foreach my $p (@prereqs) {
                    print "\t" . $p->get_column('name') . " ";
                    my ( $p_min, $p_max );
                    my $pre_course = $p->precourse();
                    my $required   = $p->get_column('required');
                    my $coreq      = $p->get_column('coreq');

                    if ( defined $pre_course ) {

                        #say Dumper $pre_course;
                        $p_min = $pre_course->get_column('min_depth');
                        $p_max = $pre_course->get_column('max_depth');
                        say "\t"
                          . $pre_course->get_column('id')
                          . " has min $p_min and max $p_max";

                        if ( $coreq == 1 ) {

                            # check to make sure there is not a cycle
                            my $cycle          = 0;
                            my @prereq_prereqs = $pre_course->prereqs();
                            foreach my $pp (@prereq_prereqs) {
                                my $pp_id = $pp->get_column('req');
                                $cycle = 1 if ( $pp_id = $cid );
                            }
                            if ($cycle) {
                                say "\t\tcycle detected";
                                $p_min = 0 if ( $p_min < 0 );
                                $p_max = 0 if ( $p_max < 0 );
                            }
                        }
                    }
                    else {
                        # prereqs without corresponding courses will
                        # be considered min depth of 0 and max depth
                        # of 1

                        # a coreq should default to 0,1
                        if ( $coreq == 1 ) {
                            $p_min = 0;
                            $p_max = 1;
                        }
                        else {
                            $p_min = -1;
                            $p_max = 0;
                        }
                    }

                    # if the requirement is a coreq then keep the same
                    # depth, otherwise add one
                    if ( $coreq == 0 ) {
                        $p_min += 1;
                        $p_max += 1;
                    }

                    # if there are optional prereqs then they will be
                    # lumped together with the idea that at least one
                    # of them must be satisfied
                    if ($required) {
                        $min_depth = $p_min
                          if ( ( !defined $min_depth )
                            || ( $p_min > $min_depth ) );
                        $max_depth = $p_max
                          if ( ( !defined $max_depth )
                            || ( $p_max > $max_depth ) );
                    }
                    else {

                        $min_opt = $p_min
                          if ( ( !defined $min_opt ) || ( $p_min < $min_opt ) );
                        $max_opt = $p_max
                          if ( ( !defined $max_opt ) || ( $p_max > $max_opt ) );
                    }

                    if ( defined $min_opt ) {
                        say
"$p_min ($min_opt -- $min_depth) $p_max ($max_opt -- $max_depth)";
                    }
                    else {
                        say "$p_min ( -- $min_depth) $p_max ( -- $max_depth)";
                    }

                }    # foreach prereq

                # now factor in the optional ones
                if ( defined $min_opt ) {
                    $min_depth = $min_opt
                      if ( ( !defined $min_depth )
                        || ( $min_opt > $min_depth ) );
                    $max_depth = $max_opt
                      if ( ( !defined $max_depth )
                        || ( $max_opt > $max_depth ) );
                }

                say "\t\t $min_depth $max_depth";

                # -1 should only show up here if there was an unprocessed prereq
                if ( $min_depth == -1 ) {
                    push @future, $course;
                }
                else {
                    $course->set_column( 'min_depth', $min_depth );
                    $course->set_column( 'max_depth', $max_depth );
                    $course->update;
                }

            }    # if there are prereqs

        }    # while processing this pass

        @current = @future;
        @future  = ();

    }    # while there are more courses to process

}    # calc_depth

# calc_ancestors will populate a relation R where a R b if a is an ancestor of
# b, there will be an attribute required saying whether it is a required
# ancestor (versus an optional one).  Another attribute depth will indicate
# how deep the ancestry is

sub calc_ancestors {
    my $s = shift;

# start with all of the prereqs, if there is a direct relationship, then there is an ancestry of depth one

    my @prereqs =
      $s->resultset('Prereq')->search( { 'req' => { '!=' => undef } } );

    # this is a table of all of the prerequisites each course has
    my $course_table = {};

    my $count = 0;

    # now insert these into the ancestry table
    foreach my $p (@prereqs) {
        my %dat  = $p->get_columns();
        my $data = \%dat;

        #$data->{'depth'} = 1 - $data->{'coreq'};

        # cache the prereq data by course
        $course_table->{ $data->{'course'} } = []
          unless ( defined $course_table->{ $data->{'course'} } );
        push @{ $course_table->{ $data->{'course'} } }, $data;

        my $ancestor =
          $s->resultset('Ancestor')
          ->find_or_create(
            { 'ancestor' => $data->{'req'}, 'course' => $data->{'course'} } );

        #	update_ancestor ($ancestor, $data);
        $ancestor->update();
        $count++;
    }

    my $oldcount = 0;

    # now iterate until we reach quiessence
    while ( $oldcount != $count ) {
        say "oldcount $oldcount count $count";
        $oldcount = $count;
        $count    = 0;
        my @ancestor_list = $s->resultset('Ancestor')->all();
        foreach my $a (@ancestor_list) {
            my $aid        = $a->get_column('ancestor');
            my $descendant = $a->get_column('course');

 # now check that all of the ancestors prereqs are ancestors of this course also
            foreach my $pre_data ( @{ $course_table->{$aid} } ) {
                $count++;
                my $new_ancestor = $s->resultset('Ancestor')->find_or_create(
                    {
                        'ancestor' => $pre_data->{'req'},
                        'course'   => $descendant
                    }
                );
                $new_ancestor->update();
            }    # propagate prereqs
        }    # go through existing ancestors
    }

}    # calc_ancestors

sub update_ancestor {
    my $ancestor = shift;
    my $data     = shift;

    if ( $data->{'depth'} < $ancestor->get_column('depth') ) {

    }
    if ( $data->{'required'} == 1 ) {
        $ancestor->set_column( 'required', 1 );
    }
    return;
}
