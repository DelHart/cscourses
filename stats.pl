#!/usr/bin/env perl

use feature say;
use strict;
use warnings;

use Statistics::Basic qw(:all);

use Data::Dumper;
use CSchema;

my $s = CSchema->connect('dbi:SQLite:courses.sqlite')
  || die "could not open database";

# put various things into arrays
# start with the number of prereqs for elements in the connected component
my $schools = {};

my @type_names = qw (two four both mast doct);

my $req_split = {};

my $sctypes = {};
foreach my $tn (@type_names) {
    $sctypes->{$tn} = { 'descendants' => [],
			'parents' => [],
			'others'  => [],
			'any'     => [],
			'count'   => 0,
    };
}

my @schools = $s->resultset('School')->search ( {'pparser' => { '>' => '-1'} });
foreach my $sc (@schools) {
    my $sid  = $sc->get_column ('school');
    my $type = $sc->get_column ('type');
    my $mc   = $sc->get_column ('max_comp');

    my $schools->{$sid} = { 
	'school' => $sid,
	'type'   => $type,
	'mc'     => $mc,
    };

	$sctypes->{$type}->{'count'} += 1;

    my @courses = $s->resultset('Course')->search ( { 'school' => $sid, 'component' => { '<>' => $mc}, 'useful' => 1 });
    foreach my $course (@courses) {
	my $ct = $course->course_type();
#	print Dumper $ct;

	my $da = $ct->get_column ('dir_ancestors');
	my $dd = $ct->get_column ('dir_descendants');
	my $nc = $ct->get_column ('non_course_reqs');
	my $any = $nc+$da;


	push @{$sctypes->{$type}->{'descendants'}}, $dd;
	push @{$sctypes->{$type}->{'parents'}}, $da;
	push @{$sctypes->{$type}->{'others'}}, $nc;
	push @{$sctypes->{$type}->{'any'}}, $any;

    $req_split->{$any} = { 'count'=>0, 'course' => 0, 'other'=>0} unless defined $req_split;
    $req_split->{$any}->{'count'} += 1;
    $req_split->{$any}->{'course'} += $da;
    $req_split->{$any}->{'other'} += $nc;

    }

    
}

# print Dumper $sctypes;

foreach my $tn (@type_names) {
    my $mdesc = mean @{$sctypes->{$tn}->{'descendants'}};
    my $manc = mean @{$sctypes->{$tn}->{'parents'}};
    my $mother = mean @{$sctypes->{$tn}->{'others'}};
    my $many = mean @{$sctypes->{$tn}->{'any'}};

    print "$tn: desc $mdesc parents $manc others $mother any $many \n";
    print "descendants: $sctypes->{$tn}->{'count'} \n";
    print_counts ($sctypes->{$tn}->{'descendants'});
    print "ancestors: \n";
    print_counts ($sctypes->{$tn}->{'parents'});
    print "others: \n";
    print_counts ($sctypes->{$tn}->{'others'});
    print "any: \n";
    print_counts ($sctypes->{$tn}->{'any'});
    print "\n\n";
#    print "descendants: " . ( get_histogram $sctypes->{$tn}->{'descendants'}, 10, 1, 1 ) . "\n";
}

print Dumper $req_split;


sub print_counts {
    my $array = shift;

    my $size = $#$array + 1;

    my $data = {};
    foreach my $a (@$array) {
	$data->{$a} = 0 unless defined ($data->{$a});
	$data->{$a} += 1;
    }

    foreach my $k (sort { $a <=> $b} keys %$data) {
	print "\t$k " . "$data->{$k}\t" . $data->{$k} / $size . "\n";
    }

}
