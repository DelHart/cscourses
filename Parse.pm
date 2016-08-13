package Parse;

use Exporter;

our @ISA= qw(Exporter);
our @EXPORT=qw(sentence_parse);

sub sentence_parse {

    my $full = shift;
    my $p    = shift;

    my $data = {
        'desc'     => '',
        'coreq'    => '',
        'prereq'   => '',
        'schedule' => '',
        'reqs'     => [],
    };

    return $data unless defined $full;

    # break it up into sentences then scan for different things
    my @sentences = split '\.', $full;
    foreach my $s (@sentences) {
        my $found = 0;
        foreach my $pair (@$p) {

            #say "checking for $$pair[0] in $s";
            if ( $s =~ m/$$pair[0]/ ) {
                $data->{ $$pair[1] } .= $1 if ( defined $1 );
                $found = 1;
                last;
            }

            #say "\tnotfound";
        }
        if ( $found == 0 ) {
            $data->{'desc'} .= $s . '.';
        }
    }

    return $data;

}    # sentence parse

1;
