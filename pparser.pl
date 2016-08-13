#!/usr/bin/env perl

use feature say;
use strict;
use warnings;
use Parse qw (sentence_parse);

use Getopt::Long;

use Data::Dumper;
use CSchema;

our $COURSES = {};

my $sid;
my $commit     = 0;
my $parser     = 100;
my $req_parser = 0;

GetOptions(
    "school=i" => \$sid,
    "parser=i" => \$parser,
    "req=i"    => \$req_parser,
    "db"       => \$commit
) or die("Error in command line args");

my $s = CSchema->connect('dbi:SQLite:courses.sqlite')
  || die "could not open database";

my $req_parsers = {
    '0' => sub {
        my $course = shift;
        my $data   = $COURSES->{$course}->{'data'};
        my $dept   = $COURSES->{$course}->{'course'}->get_column('dept');

        and_or_parse( $data, $dept, 'prereq' );
        and_or_parse( $data, $dept, 'coreq' );

        map { $_->{'course'} = $course; } @{ $data->{'reqs'} };

        return;
    },
};

my $parsers = {
    '0' => sub {

        # plattsburgh
        # brockport
        # Ulster
        my $c            = shift;
        my @parsing_info = (
            [ 'Liberal arts',            'other' ],
            [ '\((.*?Fall.*?)\)',        'schedule' ],
            [ '\((.*?Spring.*?)\)',      'schedule' ],
            [ '\((.*?Occasional.*?)\)',  'schedule' ],
            [ '.*?[Cc]orequi.*?:(.*)$',  'coreq' ],
            [ '.*?[Pp]rerequi.*?:(.*)$', 'prereq' ]
        );

        my $full = $c->get_column('full');
        return sentence_parse( $full, \@parsing_info );

    },
    '1' => sub {

        # potsdam
        # suny adirondack
        my $c            = shift;
        my @parsing_info = (
            [ '(.*?Fall.*?$)',           'schedule' ],
            [ '(.*?Spring.*?$)',         'schedule' ],
            [ '(.*?arrants.*?$)',        'schedule' ],
            [ '.*?[Cc]orequi.*?:(.*)$',  'coreq' ],
            [ '.*?[Pp]rerequi.*?:(.*)$', 'prereq' ]
        );

        my $full = $c->get_column('full');
        return sentence_parse( $full, \@parsing_info );

    },
    '2' => sub {

        # albany
        my $c            = shift;
        my @parsing_info = (
            [ 'graded',                  'other' ],
            [ '(.*?offered.*?$)',        'schedule' ],
            [ '.*?[Cc]orequi.*?:(.*)$',  'coreq' ],
            [ '.*?[Pp]rerequi.*?:(.*)$', 'prereq' ]
        );

        my $full = $c->get_column('full');
        return sentence_parse( $full, \@parsing_info );
    },
    '3' => sub {

        # alfred
        my $c = shift;
        my @parsing_info =
          ( [ '.*?course assumes a prerequisite (.*)$', 'prereq' ] );

        my $full = $c->get_column('full');
        return sentence_parse( $full, \@parsing_info );
    },
    '4' => sub {

        # binghamton
        my $c            = shift;
        my @parsing_info = (
            [ 'raduate',                 'other' ],
            [ 'redits',                  'other' ],
            [ '(.*?ffered.*?$)',         'schedule' ],
            [ '.*?[Cc]orequi.*?:(.*)$',  'coreq' ],
            [ '.*?[Pp]rerequi.*?:(.*)$', 'prereq' ]
        );

        my $full = $c->get_column('full');
        return sentence_parse( $full, \@parsing_info );
    },
    '5' => sub {

        # broome
        my $c            = shift;
        my @parsing_info = (
            [
                '.*?Prerequisite- Corequisite\s*[Cc]orequi.*?:(.*)Credits',
                'coreq'
            ],
            [
                '.*?Prerequisite- Corequisite\s*[Pp]rerequi.*?:(.*)Credits',
                'prereq'
            ],
            [ '.*?ontinuation of.*?(CST \d\d\d).*$', 'prereq' ],
            [ '.*an be taken after(.*)$',            'prereq' ]
        );

        my $full = $c->get_column('full');
        return sentence_parse( $full, \@parsing_info );

    },
    '6' => sub {

        # cayuga
        my $c            = shift;
        my @parsing_info = (
            [ '\shour',                     'other' ],
            [ '^(.*?Offered.*)$',                     'schedule' ],
            [ '.*?[Cc]oncurrent.*?:(.*)$', 'coreq' ],
            [ '.*?[Pp]rerequi.*?:(.*)$',   'prereq' ]
        );

        my $full = $c->get_column('full');
        $full =~ s/C\.S\./CS/g if ( defined $full );
        return sentence_parse( $full, \@parsing_info );

    },
    '7' => sub {

        # Cobleskill
        my $c            = shift;
        my @parsing_info = (
            [ '\[(.*?Fall.*?)\]',        'schedule' ],
            [ '\[(.*?Spring.*?)\]',      'schedule' ],
            [ '\((.*?Occasional.*?)\)',  'schedule' ],
            [ '.*?[Cc]o-requi.*?:(.*)$',  'coreq' ],
            [ '.*?[Pp]rerequi.*?:(.*)$', 'prereq' ]
        );

        my $full = $c->get_column('full');
        return sentence_parse( $full, \@parsing_info );

    },
    '8' => sub {

        # Corning
        my $c            = shift;
        my @parsing_info = (
            [ 'Shelf Life Alert',            'other' ],
            [ 'Fee',            'other' ],
            [ '[Ll]ecture',            'other' ],
            [ '\((.*?Fall.*?)\)',        'schedule' ],
            [ '\((.*?Spring.*?)\)',      'schedule' ],
            [ '.*?e taking.*?\s(.*)$',  'coreq' ],
            [ '.*?[Cc]o-requi.*?\s(.*)$',  'coreq' ],
            [ '.*?[Pp]rerequi.*?\s(.*)$', 'prereq' ]
        );

        my $full = $c->get_column('full');
        return sentence_parse( $full, \@parsing_info );

    },
    '9' => sub {

        # Delhi
        my $c            = shift;
        my @parsing_info = (
            [ '(.*?Fall.*?)',        'schedule' ],
            [ '(.*?Spring.*?)',      'schedule' ],
            [ '(.*?On Demand.*?)',      'schedule' ],
            [ '.*?[Cc]o-requi.*?\s(.*)$',  'coreq' ],
            [ '.*?[Pp]rerequi.*?\s(.*)$', 'prereq' ]
        );

        my $full = $c->get_column('full');
	$full =~ s/\(\d.*?\)/\./ if (defined $full);
        return sentence_parse( $full, \@parsing_info );

    },
    '10' => sub {

        # farmingdale
        my $c            = shift;
        my @parsing_info = (
            [ 'Liberal arts',            'other' ],
            [ '\((.*?Fall.*?)\)',        'schedule' ],
            [ '\((.*?Spring.*?)\)',      'schedule' ],
            [ '\((.*?Occasional.*?)\)',  'schedule' ],
            [ '.*?[Cc]orequi.*?:(.*)$',  'coreq' ],
            [ '.*?[Pp]requi.*?:(.*)$', 'prereq' ],
            [ '.*?[Pp]rerequi.*?:(.*)$', 'prereq' ]
        );

        my $full = $c->get_column('full');
	$full =~ s/\(\d.*?\)/\./ if (defined $full);
	$full =~ s/Credits: \d// if (defined $full);
	$full =~ s/or higher/orhigher/ if (defined $full);
	$full =~ s/Coreq/\.Coreq/ if (defined $full);
        return sentence_parse( $full, \@parsing_info );

    },
    '11' => sub {

        # geneseo
        my $c            = shift;
        my @parsing_info = (
            [ '^(.*?Offered.*)$',                     'schedule' ],
            [ '.*?[Cc]orequi.*?:(.*)$', 'coreq' ],
            [ '.*?[Pp]rerequi.*?:(.*)$',   'prereq' ],
            [ '.*?[Pp]reequi.*?:(.*)$',   'prereq' ]
        );

        my $full = $c->get_column('full');
	$full =~ s/Coreq/\.Coreq/ if (defined $full);
        return sentence_parse( $full, \@parsing_info );

    },
    '12' => sub {

        # Jefferson
        my $c            = shift;
        my @parsing_info = (
            [ '\((.*?Departmental.*?)',        'other' ],
            [ '.*?[Cc]orequi.*?:(.*)$',  'coreq' ],
            [ '.*?[Pp]rerequi.*?:(.*)$', 'prereq' ]
        );

        my $full = $c->get_column('full');
	$full =~ s/\d cr\..*?\)// if (defined $full);
        return sentence_parse( $full, \@parsing_info );

    },
    '13' => sub {

        # Nassau
        my $c            = shift;
        my @parsing_info = (
            [ 'Laboratory fee',            'other' ],
            [ 'remediation requirements',            'other' ],
            [ '^(.*?Offered.*?)$',        'schedule' ],
            [ 'SUNY',            'other' ],
            [ ':(.*?)\(with concurrency\)',  'coreq' ],
            [ '.*?[Pp]rerequi.*?:(.*)$', 'prereq' ]
        );

        my $full = $c->get_column('full');
	$full =~ s/concurrency.*?permitted.*?\./\./ if (defined $full);
        return sentence_parse( $full, \@parsing_info );

    },
    '14' => sub {

        # niagra
        my $c            = shift;
        my @parsing_info = (
            [ '\((.*?Fall.*?)\)',        'schedule' ],
            [ '\((.*?Spring.*?)\)',      'schedule' ],
            [ '\((.*?Occasional.*?)\)',  'schedule' ],
            [ '.*?[Cc]orequi.*?:(.*)$',  'coreq' ],
            [ '.*?[Pp]re-?requi.*?:(.*)$', 'prereq' ]
        );

        my $full = $c->get_column('full');
	$full =~ s/\.\)/\)\./g if (defined $full);
        return sentence_parse( $full, \@parsing_info );

    },
    '15' => sub {

        # old westbury
        my $c            = shift;
        my @parsing_info = (
            [ '(.*?Offered.*)',        'schedule' ],
            [ '.*?[Cc]orequi.*?:(.*)$',  'coreq' ],
            [ '.*?[Pp]rerequi.*?:(.*)$', 'prereq' ]
        );

        my $full = $c->get_column('full');
        return sentence_parse( $full, \@parsing_info );

    },
    '16' => sub {

        # Oneonta
        my $c            = shift;
        my @parsing_info = (
            [ '(.*?Offered.*)',        'schedule' ],
            [ '.*?[Cc]orequi.*?:(.*)$',  'coreq' ],
            [ '.*?[Pp]rerequi.*?:(.*)$', 'prereq' ]
        );

        my $full = $c->get_column('full');
	$full =~ s/\sCS\s/ CSCI /g if (defined $full);
        return sentence_parse( $full, \@parsing_info );

    },
    '17' => sub {

        # orange county
        my $c            = shift;
        my @parsing_info = (
            [ '.*?oncurrent enrollment in(.*)$',  'coreq' ],
            [ '.*?[Cc]orequi.*?:(.*)$',  'coreq' ],
            [ '.*?[Pp]rerequi.*?:(.*)$', 'prereq' ],
            [ '.*?Enrollment by(.*)$', 'prereq' ]
        );

        my $full = $c->get_column('full');
	$full =~ s/or higher/orhigher/g if (defined $full);
        return sentence_parse( $full, \@parsing_info );

    },
    '18' => sub {

        # oswego
        my $c            = shift;
        my @parsing_info = (
            [ '^(.*?Offered.*)$',                     'schedule' ],
            [ '.*?[Cc]orequi.*?:(.*)$', 'coreq' ],
            [ '.*?PREREQ*?:(.*)$',   'prereq' ],
            [ '.*?[Pp]rerequi.*?:(.*)$',   'prereq' ]
        );

        my $full = $c->get_column('full');
	$full =~ s/Credits?:?\s+\d//g if (defined $full);
	$full =~ s/\d\s+Credits?//g if (defined $full);
        return sentence_parse( $full, \@parsing_info );

    },

    '100' => sub {
	my $c = shift;
	return mostly_parsed ($c);
    },
};

open my $html_file, '>', "compare.html" || die "could not open output file";

my $school = $s->resultset('School')->find( { 'school' => $sid } );

my $name = $school->get_column('name');

say $html_file "<html><h1>$name</h1>";

say $html_file
"<table border='1'><tr><td>Course</td><td>Course Desc</td><td>prereq</td><td>list</td><td>co req</td><td>desc</td><td>schedule</td></tr>";

say $html_file "</tr>";

my @courses = $s->resultset('Course')
  ->search( { 'school' => $sid }, { 'order_by' => 'id ASC' } );

# first pull in the info about each course
foreach my $c (@courses) {
    my $course = $c->get_column('course');

    if ( !defined $course ) {

        my $num = $c->get_column('num');

        $course = 1000000 * $sid + $num * 10;
        while ( defined $COURSES->{$course} ) {
            $course++;
        }
        $c->set_column( 'course', $course );
        $c->update;
    }
    $COURSES->{$course}->{'course'} = $c;
    $COURSES->{$course}->{'id'}     = $c->get_column('id');
    $COURSES->{$course}->{'data'}   = $parsers->{$parser}($c);
}

# now try to figure out the prereqs
foreach my $c (@courses) {
    my $course = $c->get_column('course');
    $req_parsers->{$req_parser}($course);
}

# now display the data
foreach my $c (@courses) {
    my $id   = $c->get_column('id');
    my $full = $c->get_column('full');
    $full = '' unless defined $full;
    my $course = $c->get_column('course');
    my $data   = $COURSES->{$course}->{'data'};
    print $html_file "<tr><td>$id ($course)</td><td>$full</td>";

    print $html_file "<td>" . $data->{'prereq'} . "</td><td><table>";
    foreach my $item ( @{ $data->{'reqs'} } ) {
        print $html_file "<tr><td> "
          . $item->{'coreq'} . ':'
          . $item->{'required'} . ':'
          . $item->{'name'};
        print $html_file "(" . $item->{'req'} . ")"
          if ( defined $item->{'req'} );
        print $html_file "</td></tr>";
    }
    print $html_file
"</table></td><td>$data->{'coreq'}</td><td>$data->{'desc'}</td><td>$data->{'schedule'}</td>";

    if ($commit) {
        $c->set_column( 'description', $data->{'desc'} );
        $c->set_column( 'schedule',    $data->{'schedule'} );
        $c->set_column( 'prereqs',     $data->{'prereq'} );
        $c->set_column( 'coreqs',      $data->{'coreq'} );
        $c->update;

        # now put the prerequisites in
        foreach my $item ( @{ $data->{'reqs'} } ) {
            $s->resultset('Prereq')->find_or_create($item);
        }

    }

    say $html_file "</tr>";
}

say $html_file "</table></html>";

close $html_file;


sub find_course {
    my $id = shift;

    foreach my $item ( keys %$COURSES ) {
        return $item if ( $COURSES->{$item}->{'id'} eq $id );
    }

    return undef;

}    # find_course

sub and_or_parse {

    my $data  = shift;
    my $dept  = shift;
    my $desc  = shift;
    my $coreq = 0;
    $coreq = 1 if ( $desc eq 'coreq' );

    my @tmp_list;
    my @list;

    my $text = $data->{$desc};

    # change the grade or better text
    $text =~ s/or better/orbetter/g;

    my @and_list = split m[(?:,|;| and |&)], $text;

    if ( $#and_list >= 0 ) {
        foreach my $item (@and_list) {
	    next if ($item =~ /^\s*$/);
	    next if ($item =~ /None/);
	$item =~ s/\(//;
	$item =~ s/\)//;
            push @tmp_list,
              { 'name' => $item, 'required' => 1, 'coreq' => $coreq };
        }
    }

    foreach my $titem (@tmp_list) {
        my @or_list = split / or /, $titem->{'name'};

        if ( $#or_list >= 1 ) {
            foreach my $item (@or_list) {
		next if ($item =~ /^\s*$/);
		next if ($item =~ /None/);
	$item =~ s/\(//;
	$item =~ s/\)//;
                push @list,
                  { 'name' => $item, 'required' => '0', 'coreq' => $coreq };
            }
        }
        else {
            push @list, $titem;
        }
    }

    # now iterate through the list and look for course matches
    foreach my $item (@list) {
        my $r = $item->{'name'};

	#print "req is =$r= looking for ";
        # the full id
        if ( $r =~ m/(\S\S\S\S?)\/(\S\S\S\S?)\s+?(\d\d\d\d?)/ ) {
	    my $dept1 = find_course("$1$3");
	    if (defined $dept1) {
		$item->{'req'} = $dept1;
	    }
	    else {
		$item->{'req'} = find_course("$2$3");
	    }
	#    say "3 - $1$2";
	}
        elsif ( $r =~ m/$dept\s?(\d\d\d\S?)/ ) {

            #		my $cid = $sid * 1000000 + $1 * 10;
            $item->{'req'} = find_course("$dept$1");
	#    say "1 - $dept$1";

        }

        # just the number, usually after a previous one had the id
        elsif ( $r =~ m/^\s*?(\d\d\d\S?)/ ) {
            $item->{'req'} = find_course("$dept$1");
	#    say "2 - $dept$1";
        }
# or maybe a course under a different code
        elsif ( $r =~ m/(\S\S\S\S?)\s?(\d\d\d\S?)/ ) {
            $item->{'req'} = find_course("$1$2");
	#    say "3 - $1$2";
	}
	else {
	    say "failed to find =$r=";
	}
    }

    push @{ $data->{'reqs'} }, @list;

    return;
}

sub mostly_parsed {

    my $c = shift;

    my $data = {
        'desc'     => $c->get_column('description'),
        'coreq'    => $c->get_column('coreqs'),
        'prereq'   => $c->get_column('prereqs'),
        'schedule' => $c->get_column('schedule'),
        'reqs'     => [],
    };
    
    $data->{'prereq'} = '' unless defined ($data->{'prereq'});
    $data->{'coreq'} = '' unless defined ($data->{'coreq'});
    $data->{'schedule'} = '' unless defined ($data->{'schedule'});

    $data->{'prereq'} =~ s/or [Hh]igher/orhigher/;
    $data->{'coreq'} =~ s/or [Hh]igher/orhigher/;

    return $data;

}    # mostly_parsed

