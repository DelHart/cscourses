#!/usr/bin/env perl

# notes
# min credit values set to 0 for some (broome)
# fractional credits (corning)

use feature say;
use strict;
use warnings;

use Data::Dumper;
use Mojo::DOM;
use Mojo::UserAgent;
use File::Slurp;

use Parse qw(sentence_parse);

use CSchema;

my $s = CSchema->connect('dbi:SQLite:courses.sqlite')
  || die "could not open database";

my $schools = {
    '1' => {
        'name'   => 'SUNY Plattsburgh',
        'parser' => sub {
            my $string =
              read_file(
                '/home/del/repos/projects/cscourses/webpages/plattsburgh.html');
            my $q = Mojo::DOM->new($string);

            my $courses = {};

            #print Dumper $q;
            for my $e ( $q->find('h4')->each ) {
                $e->text =~
                  m/(\w\w\w)(\d\d\d) - (.*?) \((\d) (?<maxc>.*?)?cr\./;

                #$e->text =~ m/(\w\w\w)(\d\d\d) - (.*?) \((\d) (\d+)? cr.\)/;
                my $id = "$1$2";
                if ( defined $id ) {
                    $courses->{$id} = {
                        'id'      => $id,
                        'dept'    => $1,
                        'num'     => $2,
                        'title'   => $3,
                        'credits' => $4,
                    };
                    my $maxcred = '';
                    my $m       = $+{maxc};
                    $maxcred = substr( $m, 3 ) if ( $m =~ m/\d+/ );
                    $courses->{$id}->{'maxcredits'} = $maxcred;

                    my $desc = $e->next->text;
                    $courses->{$id}->{'full'} = $desc;
                    if ( $desc =~ m/Coreq/ ) {
                        $desc =~ m/(.*?)Coreq.*?: (.*)$/;
                        $courses->{$id}->{'description'} = $1;
                        my $nest = $2;
                        if ( $nest =~ m/Prereq/ ) {
                            $nest =~ m/(.*?)Prere.*?: (.*)$/;
                            $courses->{$id}->{'coreqs'}  = $1;
                            $courses->{$id}->{'prereqs'} = $2;
                        }
                        else {
                            $courses->{$id}->{'coreqs'} = $nest;
                        }
                    }
                    else {
                        if ( $desc =~ m/Prereq/ ) {
                            $desc =~ m/(.*?)Prere.*?: (.*)$/;
                            $courses->{$id}->{'description'} = $1;
                            $courses->{$id}->{'prereqs'}     = $2;
                        }
                        else {
                            $desc =~ m/(.*?)$/;
                            $courses->{$id}->{'description'} = $1;
                        }
                    }

                }
                else {
                    warn "could not figure out id for $id\n";
                }
            }
            return $courses;
        },

    },

    '2' => {
        'name'   => 'SUNY Potsdam',
        'parser' => sub {
            my $string =
              read_file(
                '/home/del/repos/projects/cscourses/webpages/potsdam.html');
            my $q = Mojo::DOM->new($string);

            my $courses = {};

            my $coll = $q->find('a');
            foreach my $item ( $coll->each ) {
                my $id = $item->attr('name');
                $id =~ m/(\w\w\w)(\d\d\d)/;
                my $dept = $1;
                my $num  = $2;

                my $title_node = $item->parent->parent->next;
                my $title      = $title_node->all_text;

                my $credits_node = $title_node->next;
                my $cr           = $credits_node->all_text;
                my $maxcr;
                my $credits;
                if ( $cr =~ m/(\d+)\-(\d+)/ ) {
                    $credits = $1;
                    $maxcr   = $2;
                }
                else {
                    $cr =~ m/(\d+)/;
                    $credits = $1;
                }
                my $desc_node = $credits_node->parent->next;
                my $full      = $desc_node->all_text;
                my $desc;
                my $prereq = '';
                my $coreq  = '';

                if ( $full =~ m/Prereq/ ) {
                    $full =~ m/(.*?)Prere.*?: (.*)$/;
                    $desc   = $1;
                    $prereq = $2;
                    my $nest = $prereq;

                    # spelling mistake !!!!
                    if ( $nest =~ m/(.*?)Co(?:re)?req.*:(.*)/ ) {
                        $prereq = $1;
                        $coreq  = $2;
                    }
                }
                else {
                    if ( $full =~ m/(.*?)Co(?:re)?req.*:(.*)/ ) {
                        $desc  = $1;
                        $coreq = $2;
                    }
                    else {
                        $full =~ m/(.*?)$/;
                        $desc = $1;
                    }
                }

                if ( defined $id ) {
                    $courses->{$id} = {
                        'id'          => $id,
                        'dept'        => $dept,
                        'num'         => $num,
                        'title'       => $title,
                        'credits'     => $credits,
                        'maxcredits'  => $maxcr,
                        'full'        => $full,
                        'description' => $desc,
                        'prereqs'     => $prereq,
                        'coreqs'      => $coreq,
                    };
                }
            }

            return $courses;

        },

    },

    '3' => {
        'name'   => 'SUNY Adirondack',
        'parser' => sub {
            return xml_banner_import(
'/home/del/repos/projects/cscourses/webpages/suny_adirondack.xml'
            );
        }

    },
    '4' => {
        'name' => 'SUNY Albany',
        'url'  => 'http://www.albany.edu/undergraduate_bulletin/I_csi.html',

        'parser' => sub {

            my $courses = {};
            my $string =
              read_file(
                '/home/del/repos/projects/cscourses/webpages/albany.html');
            my $q = Mojo::DOM->new($string);

            my $item = $q->find('.text-box')->[0];

            my $coll = $item->children('p');
            foreach my $child ( $coll->each ) {

                my $strong = $child->children('strong')->[0];
                next unless defined $strong;
                my $title_text = $strong->text;
                my $full       = $child->text;

                my ( $id, $num, $title, $credits, $maxcr, $desc, $prereq,
                    $coreq );
                if ( $title_text =~ m/.*?CSI\ (\d\d\d)(\w?)\ (.*?)\ \((\d)\)/ )
                {
                    $num     = $1;
                    $id      = "CSI$1$2";
                    $title   = $3;
                    $credits = $4;
                }
                elsif ( $title_text =~
                    m/.*?CSI\ (\d\d\d)(\w?)\ (.*?)\ \((\d)-(\d+)\)/ )
                {
                    $num     = $1;
                    $id      = "CSI$1$2";
                    $title   = $3;
                    $credits = $4;
                    $maxcr   = $5;
                }

                if ( $full =~ m/Prerequ.*?coreq/ ) {
                    $full =~ m/(.*?)Pre.*?: (.*?)\./;
                    $desc  = $1;
                    $coreq = $2;
                }
                elsif ( $full =~ m/Prereq/ ) {
                    if ( $full =~ m/Coreq/ ) {
                        $full =~ m/(.*?)Prere.*?: (.*?)\..*?Coreq.*?:(.*?)\./;
                        $desc   = $1;
                        $prereq = $2;
                        $coreq  = $3;
                    }
                    else {
                        $full =~ m/(.*?)Prere.*?: (.*?)\./;
                        $desc   = $1;
                        $prereq = $2;
                    }
                }
                elsif ( $full =~ m/Coreq/ ) {
                    $full =~ m/(.*?)Core.*?: (.*?)\./;
                    $desc  = $1;
                    $coreq = $2;
                }
                else {
                    $desc = $full;
                }

                if ( defined $id ) {
                    $courses->{$id} = {
                        'id'          => $id,
                        'dept'        => "CSI",
                        'num'         => $num,
                        'title'       => $title,
                        'credits'     => $credits,
                        'maxcredits'  => $maxcr,
                        'full'        => $full,
                        'description' => $desc,
                        'prereqs'     => $prereq,
                        'coreqs'      => $coreq,
                    };
                }
            }
            return $courses;

        },

    },
    '5' => {
        'name' => 'SUNY Alfred',

        'parser' => sub {

            my $translate = {
                'num'         => 'Course',
                'title'       => 'Title',
                'dept'        => 'Subj_Code',
                'full'        => 'Description',
                'description' => 'Description',
                'credits'     => 'Credits',
                'prereqs'     => 'Prereqs',
                'coreqs'      => 'Coreqs',
            };

            my $courses = {};
            my $string =
              read_file(
                '/home/del/repos/projects/cscourses/webpages/alfred/scr0007.xml'
              );

            my $q = Mojo::DOM->new($string);

            my $coll = $q->find('Course');
            foreach my $item ( $coll->each ) {

                my $c = {};
                foreach my $key ( keys %$translate ) {
                    my $val = $item->find( $translate->{$key} );
                    if ( defined $val->[0] ) {
                        $c->{$key} = $val->[0]->all_text;
                    }
                    else {
                    }
                }
                my $id = $c->{'dept'} . $c->{'num'};
                $c->{'id'} = $id;
                $courses->{$id} = $c;
            }

            return $courses;

        },

    },
    '6' => {
        'name' => 'SUNY Binghamton',

        'parser' => sub {

            my $courses = {};
            my $string =
              read_file(
'/home/del/repos/projects/cscourses/webpages/binghamton_official.html'
              );
            my $q = Mojo::DOM->new($string);

            my $item = $q->find('.datadisplaytable')->[0];

            my $title_row = $item->children('tbody')->[0]->children('tr')->[0];
            while ( defined $title_row ) {
                my $title_text = $title_row->all_text;
                my $desc_row   = $title_row->next;
                my $full       = $desc_row->children('td')->[0]->text;

                my ( $id, $num, $title, $credits, $maxcr, $desc, $prereq,
                    $coreq );
                if ( $title_text =~ m/.*?CS\ (\d\d\d)\ -\ (.*)$/ ) {
                    $num   = $1;
                    $id    = "CS$1";
                    $title = $2;
                }

                my @full = split( '\.', $full );
                my $end = pop @full;
                if ( $end =~ m/(\d)\ cred/ ) {
                    $credits = $1;
                }
                else {
                    $end = pop @full;
                    if ( $end =~ m/(\d)\ cred/ ) {
                        $credits = $1;
                    }
                }

                if ( $#full > 1 ) {
                    my $pre_text = pop @full;
                    if ( $pre_text =~ m/requisite/ ) {
                        if ( $pre_text =~ m/orequisite/ ) {
                            $pre_text =~ m/(.*?)orequisit.*?: (.*?)$/;
                            $coreq = $2;
                        }
                        else {
                            $pre_text =~ m/(.*?)requisit.*?: (.*?)$/;
                            $prereq = $2;
                        }
                    }
                    else {
                        my $pre_text2 = pop @full;
                        if ( $pre_text2 =~ m/requisite/ ) {
                            if ( $pre_text2 =~ m/orequisite/ ) {
                                $pre_text2 =~ m/(.*?)orequisit.*?: (.*?)$/;
                                $coreq = $2;
                            }
                            else {
                                $pre_text2 =~ m/(.*?)requisit.*?: (.*?)$/;
                                $prereq = $2;
                            }
                        }
                        else {
                            push @full, $pre_text2;
                        }
                        push @full, $pre_text;
                    }
                }
                $desc = join( '.', @full );

                if ( defined $id ) {
                    $courses->{$id} = {
                        'id'          => $id,
                        'dept'        => "CS",
                        'num'         => $num,
                        'title'       => $title,
                        'credits'     => $credits,
                        'maxcredits'  => $maxcr,
                        'full'        => $full,
                        'description' => $desc,
                        'prereqs'     => $prereq,
                        'coreqs'      => $coreq,
                    };
                }
                $title_row = $desc_row->next;
            }
            return $courses;

        },

    },
    '7' => {
        'name'   => 'SUNY Brockport',
        'parser' => sub {
            return xml_banner_import(
'/home/del/repos/projects/cscourses/webpages/brockport_csc.xml'
            );
        }

    },
    '8' => {
        'name'   => 'SUNY Broome',
        'parser' => sub {
            return xml_banner_import(
'/home/del/repos/projects/cscourses/webpages/broome.xml'
            );
        }

    },
    '9' => {
        'name'   => 'SUNY Cayuga',
        'parser' => sub {
            return xml_banner_import(
'/home/del/repos/projects/cscourses/webpages/cayuga.xml'
            );
        }

    },
    '10' => {
        'name'   => 'SUNY Cobleskill',
        'parser' => sub {
            return xml_banner_import(
'/home/del/repos/projects/cscourses/webpages/cobleskill.xml'
            );
        }

    },

    '11' => {
        'name'   => 'SUNY Corning',
        'parser' => sub {
            return xml_banner_import(
'/home/del/repos/projects/cscourses/webpages/corning.xml'
            );
        }

    },

    '12' => {
        'name'   => 'SUNY Delhi',
        'parser' => sub {
            return xml_banner_import(
'/home/del/repos/projects/cscourses/webpages/delhi.xml'
            );
        }

    },
    '13' => {
        'name'   => 'SUNY Farmingdale',
        'parser' => sub {
            return xml_banner_import(
'/home/del/repos/projects/cscourses/webpages/farmingdale.xml'
            );
        }

    },
    '14' => {
        'name'   => 'SUNY Geneseo',
        'parser' => sub {
            return xml_banner_import(
'/home/del/repos/projects/cscourses/webpages/geneseo.xml'
            );
        }

    },
    '15' => {
        'name'   => 'SUNY Jefferson',
        'parser' => sub {
            return xml_banner_import(
'/home/del/repos/projects/cscourses/webpages/jefferson.xml'
            );
        }

    },
    '16' => {
        'name'   => 'SUNY Nassau',
        'parser' => sub {
            return xml_banner_import(
'/home/del/repos/projects/cscourses/webpages/nassau.xml'
            );
        }

    },
    '17' => {
        'name'   => 'SUNY Niagra',
        'parser' => sub {
            return xml_banner_import(
'/home/del/repos/projects/cscourses/webpages/niagra.xml'
            );
        }

    },
    '18' => {
        'name'   => 'SUNY Old Westbury',
        'parser' => sub {
            return xml_banner_import(
'/home/del/repos/projects/cscourses/webpages/oldwestbury.xml'
            );
        }

    },
    '19' => {
        'name'   => 'SUNY Oneonta',
        'parser' => sub {
            return xml_banner_import(
'/home/del/repos/projects/cscourses/webpages/oneonta.xml'
            );
        }

    },
    '20' => {
        'name'   => 'SUNY Orange County',
        'parser' => sub {
            return xml_banner_import(
'/home/del/repos/projects/cscourses/webpages/orangecounty.xml'
            );
        }

    },
    '21' => {
        'name'   => 'SUNY Oswego',
        'parser' => sub {
            return xml_banner_import(
'/home/del/repos/projects/cscourses/webpages/oswego.xml'
            );
        }

    },
    '22' => {
        'name'   => 'SUNY Ulster',
        'parser' => sub {
            return xml_banner_import(
'/home/del/repos/projects/cscourses/webpages/ulster.xml'
            );
        }

    },
    '23' => {
        'name'   => 'SUNY Canton',
        'parser' => sub {
            my $courses = {};
            my $string =
              read_file(
'/home/del/repos/projects/cscourses/webpages/canton.html'
              );
            my $q = Mojo::DOM->new($string);

            my $item = $q->find('#main_left')->[0];

            my $divtitles = $item->at('div');
            my $titles = $divtitles->children('h5');
            foreach my $title_row ($titles->each ) {
                my ( $id, $num, $title, $credits, $maxcr, $desc, $prereq, $coreq );
                my $title_text = $title_row->all_text;
                my $cred_row   = $title_row->next;
		my $cred_text = $cred_row->all_text;
                my $desc_row   = $cred_row->next;
                my $full       = $desc_row->all_text;
		my $req_row     = $desc_row->next;
		if ($req_row->tag eq 'p') {
		    my $req_text = $req_row->all_text;
		    my @s = split ('\.', $req_text);

		    $s[0] =~ s/or\s+permission\s+of\s+instructor//;
		    $s[0] =~ s/Data Communications and//;
		    $s[0] =~ s/Computer Concepts and//;
		    $s[0] =~ s/Computer Concepts \&//;
		    
		    if ($s[0] =~ m/o-?requisite.*?:(.*)/) {
			$coreq = $1;
		    }
		    elsif ($s[0] =~ m/erequisite.*?:(.*)/) {
			$prereq = $1;
		    }
		    }

                if ( $title_text =~ m/.*?(\d\d\d)\ (.*)$/ ) {
                    $num   = $1;
                    $id    = "CITA$1";
                    $title = $2;
                }

		my ($sched, $creds) = split (',', $cred_text);


		if ($creds =~ m/(\d+)-(\d+)/) {
		    $credits = $1;
		    $maxcr = $2;
		}
		elsif ($creds =~ m/(\d+) or (\d+)/) {
		    $credits = $1;
		    $maxcr = $2;
		}
		elsif ($creds =~ m/(\d+)/) {
		    $credits = $1;
		    $maxcr = $1;
		}


                if ( defined $id ) {
                    $courses->{$id} = {
                        'id'          => $id,
                        'dept'        => "CITA",
			'schedule'    => $sched,
                        'num'         => $num,
                        'title'       => $title,
                        'credits'     => $credits,
                        'maxcredits'  => $maxcr,
                        'full'        => $full,
                        'description' => $full,
                        'prereqs'     => $prereq,
                        'coreqs'      => $coreq,
                    };
                }
                $title_row = $desc_row->next;
            }
            return $courses;

        },


    },
    '24' => {
        'name'   => 'Buffalo University',
        'parser' => sub {
            my $courses = {};
            my $string =
              read_file(
'/home/del/repos/projects/cscourses/webpages/univbuffalo.html'
              );
            my $q = Mojo::DOM->new($string);

            my $course_list = $q->find('.course');
            foreach my $course ($course_list->each ) {
                my ( $id, $num, $title, $credits, $maxcr, $desc, $prereq, $coreq, $sched );

		my $everything = $course->all_text;

		my $title_row = $course->at('h4');
                $title = $title_row->all_text;

		if ($title =~ m/CSE\s+(\d+)\s+/) {
		    $num = $1;
		    $title =~ s/.*?\d+\s+//;
		    $id = "CSE$num";
		}

		$desc = $course->at('.c_description')->all_text;
		my $sched_info = $everything;

		if ($sched_info =~ m/Pre-req.*?:(.*?)Grading/) {
		    $prereq = $1;
		    $prereq =~ s/Approved.*?nly\.?//;
		    $prereq =~ s/ and\s+?$//m;

		    if ($prereq =~ m/requi.*?:(.*)/) {
			$coreq = $1;
			$prereq =~ s/Co-req.*//;
		    }
		    $sched_info =~ s/Pre-req.*?Grading/Grading/;
		}
		
		if ($sched_info =~ m/Seme.*?:(.*?)Grading/) {
		    $sched = $1;
		}
		
		if ($sched_info =~ m/Cred.*?(\d+)-(\d+)\s+Semes/) {
		    $credits = $1;
		    $maxcr = $2;
		}
		elsif ($sched_info =~ m/Cred.*?(\d+)\s+Semes/) {
		    $credits = $1;
		}

		# class type, null, credits label, 
                my $cred_row   = $title_row->next->next->next->next->next->next->next->next->next;
		my $cred_text = $cred_row->all_text;

                my $full       = $desc;

                if ( defined $id ) {
                    $courses->{$id} = {
                        'id'          => $id,
                        'dept'        => "CSE",
			'schedule'    => $sched,
                        'num'         => $num,
                        'title'       => $title,
                        'credits'     => $credits,
                        'maxcredits'  => $maxcr,
                        'full'        => $full,
                        'description' => $full,
                        'prereqs'     => $prereq,
                        'coreqs'      => $coreq,
                    };
                }
            }
            return $courses;

        },


    },

    '25' => {
        'name'   => 'SUNY Stony Brook',
        'parser' => sub {
            my $courses = {};
            my $string =
              read_file(
'/home/del/repos/projects/cscourses/webpages/stonybrook.html'
              );
            my $q = Mojo::DOM->new($string);

            my $course_list = $q->find('.course');
            foreach my $course ($course_list->each ) {
                my ( $id, $num, $title, $credits, $maxcr, $desc, $prereq, $coreq, $sched );

		$num = $course->attr('id');
		$id = "CSE$num";

		my $everything = $course->all_text;

		my $title_row = $course->at('h3');
                $title = $title_row->all_text;
		$title =~ s/.*?:\s+?//;

		my $desc_row = $title_row->next;
		$desc = $desc_row->all_text;

		my $row = $desc_row;
		while ($row = $row->next) {
		    my $text = $row->all_text;
		    if ($text =~ m/[Cc]o-?req.*?:(.*)/) {
			$coreq = $1;
		    }
		    elsif ($text =~ m/[Pp]re-?req.*?:(.*)/) {
			$prereq = $1;
		    }
		    elsif ($text =~ m/(\d+)-(\d+)\s+credits/) {
			$credits = $1;
			$maxcr = $2;
		    }
		    elsif ($text =~ m/(\d+)\s+credits/) {
			$credits = $1;
		    }
		}
                my $full       = $desc;

                if ( defined $id ) {
                    $courses->{$id} = {
                        'id'          => $id,
                        'dept'        => "CSE",
			'schedule'    => $sched,
                        'num'         => $num,
                        'title'       => $title,
                        'credits'     => $credits,
                        'maxcredits'  => $maxcr,
                        'full'        => $full,
                        'description' => $full,
                        'prereqs'     => $prereq,
                        'coreqs'      => $coreq,
                    };
                }
            }
            return $courses;

        },


    },
    '42' => {
        'name'   => 'SUNY New Paltz',
        'parser' => sub {
            my $courses = {};
            my $string =
              read_file(
'/home/del/repos/projects/cscourses/webpages/newpaltz.html'
              );
            my $q = Mojo::DOM->new($string);

            my $item = $q->find('html')->[0];
	    my $row = $item->at('div');
		while ($row = $row->next) {
		    my ( $id, $num, $title, $credits, $maxcr, $desc, $prereq, $coreq, $sched, $full );
		    my $text = $row->all_text;

		    my $title_row = $row->at('h2');
		    my $title_text = $title_row->all_text;
		    
		    if ($title_text =~ m/CPS(\d+)\s+(.*)/) {
			$num = $1;
			$title = $2;
			$id = "CPS$1";
		    }

		    my $desc_row = $title_row->next;
		    $desc = $desc_row->all_text;
		    $full = $desc;

		    my $attr_list = $row->children('h3');
		    foreach my $attr ($attr_list->each) {
			my $attr_name = $attr->all_text;
			if ($attr_name =~ m/Credits/) {
			    $credits = $attr->next->all_text;
			}
			elsif ($attr_name =~ m/equisite/) {
			    $prereq = $attr->next->all_text;
			}
		    }

			if ( defined $id ) {
			    $courses->{$id} = {
				'id'          => $id,
				'dept'        => "CPS",
				'schedule'    => $sched,
				'num'         => $num,
				'title'       => $title,
				'credits'     => $credits,
				'maxcredits'  => $maxcr,
				'full'        => $full,
				'description' => $desc,
				'prereqs'     => $prereq,
				'coreqs'      => $coreq,
			    };
			}
		    }

            return $courses;
		},

    },

    '49' => {
        'name'   => 'SUNY Polytechnic',
        'parser' => sub {
            my $courses = {};
            my $string =
              read_file(
'/home/del/repos/projects/cscourses/webpages/sunyit.html'
              );
            my $q = Mojo::DOM->new($string);

            my $item = $q->find('.entry-content')->[0];
	    my $row = $item->at('p');
		    my ( $id, $num, $title, $credits, $maxcr, $desc, $prereq, $coreq, $sched, $full );
		while ($row = $row->next) {
		    my $text = $row->all_text;
		    if ($text =~ m/^CS\s+(\d+)\s+?(.*?)\(Var.*?\s+(\d+)-(\d+)\)/) {
			$num = $1;
			$title = $2;
			$credits = $3;
			$maxcr = $4;
			$id = "CS$num";
		    }
		    elsif ($text =~ m/^CS (\d+)\s+?(.*?)\((\d+)\)/) {
			$num = $1;
			$title = $2;
			$credits = $3;
			$id = "CS$num";
		    }
		    elsif ($text =~ m/\S+/) {
			my @parsing_info = (
			    [ '.*?[Cc]orequi.*?:(.*)$',  'coreq' ],
			    [ '.*?[Pp]rerequi.*?:(.*)$', 'prereq' ]
			    );
			
			my $sparse = sentence_parse( $text, \@parsing_info );
			$full = $text;
			$desc = $sparse->{'desc'};
			$prereq = $sparse->{'prereq'};
			$coreq = $sparse->{'coreq'};

			if ( defined $id ) {
			    $courses->{$id} = {
				'id'          => $id,
				'dept'        => "CS",
				'schedule'    => $sched,
				'num'         => $num,
				'title'       => $title,
				'credits'     => $credits,
				'maxcredits'  => $maxcr,
				'full'        => $full,
				'description' => $desc,
				'prereqs'     => $prereq,
				'coreqs'      => $coreq,
			    };
			}
			# reset all of the variables now
			undef $id;
			undef $sched;
			undef $num;
			undef $title;
			undef $credits;
			undef $maxcr;
			undef $full;
			undef $desc;
			undef $prereq;
			undef $coreq;
		    }
		}

            return $courses;

        },


    },

};

my $school = 5;

my $courses = &{ $schools->{$school}->{'parser'} }();
my $debug   = 0;

if ($debug) {
    print Dumper $courses;
}
else {

    # add the course into the database
    foreach my $course ( keys %$courses ) {
        my $c = $courses->{$course};

        my $row = $s->resultset('Course')->find_or_create(
            {
                'id'     => $c->{'id'},
                'school' => $school,
            }
        );

        for my $attr (
            qw (dept num title credits description maxcredits full prereqs coreqs schedule)
          )
        {
            $row->set_column( $attr, $c->{$attr} );
        }

        $row->update;

        $c->{'obj'} = $row;

    }
}

# # now process the prereqs
# foreach my $course ( keys %$courses ) {
#     my $c = $courses->{$course};
#     print "fetching $course \n";
#     my $cid    = $c->{'obj'}->get_column('course');
#     my $prereq = $c->{'prereqs'};
#     print "$course $prereq\n";
# next;

#     next unless defined $prereq;
#     # simple case, it is just one course
#     my $prow = $s->resultset('Prereq')->find_or_create(
# 	{
# 	    'course' => $cid,
# 	}
# 	);
#     if ( $prereq =~ m/(\w{2,4})(\d{2,4})/ ) {
#         my $pre_id = "$1$2";
#         my $p      = $courses->{$pre_id};
#         if ( defined $p ) {
#             my $pid = $p->{'obj'}->get_column('course');

#             $prow->set_column( 'kind', 1 );
#             $prow->set_column( 'name', $pid );
#             $prow->update;
#         }
#         else {
#             print "could not find course $pre_id\n";
#             $prow->set_column( 'kind', 0 );
#             $prow->set_column( 'name', $pre_id );
#             $prow->update;

#         } # simple matches
#     }
# }

sub xml_banner_import {

    my $file = shift;

    my $translate = {
        'num'        => 'CourseNumber',
        'title'      => 'CourseLongTitle',
        'dept'       => 'CourseSubjectAbbreviation',
        'full'       => 'CourseDescription',
        'credits'    => 'CourseCreditMinimumValue',
        'maxcredits' => 'CourseCreditMaximumValue',
    };

    my $string = read_file($file);
    my $q      = Mojo::DOM->new($string);

    my $courses = {};

    my $coll = $q->find('CourseInventory');
    foreach my $item ( $coll->each ) {

        my $c = {};
        foreach my $key ( keys %$translate ) {
            my $val = $item->find( $translate->{$key} );
            if ( defined $val->[0] ) {
                $c->{$key} = $val->[0]->all_text;
            }
            else {
            }
        }
        my $id = $c->{'dept'} . $c->{'num'};
        $c->{'id'} = $id;
        $courses->{$id} = $c;

	if ($c->{'credits'} == 0) {
	    $c->{'credits'} = $c->{'maxcredits'};
	} elsif ($c->{'credits'} < 1) {
	    $c->{'credits'} = 1;
	}


	$c->{'num'} =~ m/(\d+)\D*$/;
	$c->{'num'} = $1;

	# clear out the match
	$c->{'num'} =~ m/()/;

        # my $prereq = '';
        # my $coreq  = '';
        # my $full   = $c->{'full'};
        # next unless defined $full;

        # if ( $full =~ m/Pre\/Coreq/ ) {
        #     $full =~ m/(.*?)Pre.*?: (.*)$/;
        #     $c->{'description'} = $1;
        #     $c->{'coreqs'}      = $2;
        # }
        # elsif ( $full =~ m/Prereq/ ) {
        #     $full =~ m/(.*?)Prere.*?: (.*)$/;
        #     $c->{'description'} = $1;
        #     $c->{'prereqs'}     = $2;
        # }
        # else {
        #     $c->{'description'} = $full;
        # }

    }
    return $courses;

}
