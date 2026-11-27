my %h; for my $i (1..300000){ $h{"k$i"}=[$i,"v$i"]; } my @a=map{{id=>$_,n=>"x$_"}}1..100000; sleep 60;
