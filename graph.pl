#!/usr/bin/env perl

use strict;
use warnings;

use CSchema;

my $s = CSchema->connect('dbi:SQLite:courses.sqlite')
  || die "could not open database";

my @schools = $s->resultset('School')->search({ 'pparser' => { '>' => '-1'}});

my @prereqs = $s->resultset('Prereq')->all();

foreach my $sobj (@schools) {
    my $sid = $sobj->get_column ('school');
    open my $graphfile, '>', "graphs/$sid.gv";


print $graphfile "digraph G {\n";
foreach my $p (@prereqs) {
    my $cobj = $p->cobj();

    my $school = $cobj->get_column('school');
    next unless ($school == $sid);
    
    my $id = $cobj->get_column('id');
    my $robj = $p->precourse();
    if (defined $robj) {
	my $rid = $robj->get_column('id');
	print $graphfile "$rid -> $id ";
	if ($p->get_column('required')==0) {
	    print $graphfile '[style=dashed];';
	} elsif ($p->get_column('coreq')==1) {
	    print $graphfile '[style=dotted];';
	} 
	print $graphfile "\n";
	
    }
}
print $graphfile "}\n";

    close $graphfile;

}
