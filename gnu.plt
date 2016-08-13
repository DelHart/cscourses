#!/usr/bin/gnuplot -persist

set terminal svg
set output 'prereq_mix.svg'
set xrange [-0.5:8.5]

#set title "Prerequisite Complexity"
set xlabel "prerequisite complexity" 
set ylabel "percentage of courses" 

set style data histograms
#set style histogram rowstacked
#set boxwidth 0.95 relative
set style fill pattern border

#set boxwidth 0.5
#set style fill solid
#set style data lines

plot "prereq_mix.txt" using ($6/$3/$2)  fs pattern 3 t 'cluster courses - course only prereqs',  \
                   '' using ($7/($2*$3))  fs pattern 1 t 'cluster courses - non-course prereqs',  \
                   '' using ($11/$8/$2) fs pattern 5 t 'non-cluster courses - course prereqs',  \
                   '' using ($12/($2*$8))  fs pattern 2 t 'non-cluster courses - non-course prereqs' 
#    EOF
