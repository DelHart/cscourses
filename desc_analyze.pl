#!/usr/bin/env perl

use strict;
use warnings;

# stop words
# stemming
# parts of speech

use CSchema;

my $s = CSchema->connect('dbi:SQLite:courses.sqlite')
  || die "could not open database";

my $words = {};
my $others = {};

my @courses = $s->resultset('Course')->all();

foreach my $course (@courses) {
    my $desc   = lc ($course->get_column('title'));
    my $school = $course->get_column('school');
    my $id     = $course->get_column('id');
    next unless defined $desc;
    print "$school $id $desc\n";

    $desc =~ s/intro\s+/introduction /;
    $desc =~ s/\&\s+/and /;


    my @words = split( /\s+/, $desc );

    foreach my $i (0 .. $#words) {
        my $w = $words[$i];

        #$w =~ s/[,\.\:\(\)\;]//g;
        #$w =~ s/\W+/ /g;
        #$w =~ s/\<.*?\>//g;
        $words->{$w} = 0 unless defined( $words->{$w} );
        $words->{$w} += 1;

	$others->{$w} = {} unless defined ($others->{$w});
	my $wothers = $others->{$w};
	foreach my $j (0 .. $#words) {
	    next if ($i == $j);
	    $wothers->{$words[$j]} = 0 unless defined ($wothers->{$words[$j]});
	    $wothers->{$words[$j]} += 1;
	    
	}

    }

    foreach my $len ( 1 .. $#words - 1 ) {

        for my $i ( 0 .. $#words - $len ) {
            my @gram = ();
            foreach my $j ( $i .. ( $i + $len ) ) {
                push @gram, $words[$j];
            }
            my $gram = join( ' ', @gram );
            $words->{$gram} = 0 unless defined( $words->{$gram} );
            $words->{$gram} += 1;
        }

    }
}

print "\n\n\n";
my @sorted = sort { $words->{$a} <=> $words->{$b} } keys(%$words);

foreach my $word (@sorted) {
    print "$words->{$word}\t$word\n";
    my @osorted = sort { $others->{$word}->{$a} <=> $others->{$word}->{$b} } keys (%{$others->{$word}});
    foreach my $oword (@osorted) {
	next unless ($others->{$word}->{$oword} > 0.1 * $words->{$word});
	print "\t$others->{$word}->{$oword}\t$oword\n";
    }
}

