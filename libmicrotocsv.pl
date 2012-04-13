#!/usr/bin/perl -w
# libmicrotocsv.pl --- Parse inconsistent libMicro benchmark output!
# Author: Jean-Christophe Petkovich <me@jcpetkovich.com>
# Created: 12 Apr 2012
# Version: 0.01

use warnings;
use strict;
use autodie;
use Scalar::Util qw( looks_like_number );
use Getopt::Long qw( :config auto_help );

# Commandline options
my $data_list = "name,numsamples,mean,stddev,confidence,iterations";
GetOptions( 'data=s' => \$data_list );
my @data_list = split( /,/, $data_list );

# Patterns
my %patterns = (
    without_outliers => qr/\s+\S.*\s+(\S+)/,
    with_outliers    => qr/\s+(\S+)\s+/,
    program_marked   => qr/Running: \s+(.*)#/,
    program_unmarked => qr/(\S+)\s+\d+\s+\d+\s+\d\S+\s+\d\S+\s+/,
);
%patterns = (
    %patterns,
    name       => $patterns{program_marked},
    mean       => qr/mean/,
    stddev     => qr/stddev/,
    confidence => qr/confidence level/,
    numsamples => qr/number of samples\s+(\d+)/,
    iterations => qr/#\s*bin\/.*-B\s*(\d+)/
);

sub test_name_format {
    my $file = shift;

    my $found_marked_name = '';
    open( my $fh, '<', $file );
    while (<$fh>) {
        next if /^\s*$/;

        # If we match our pattern, the file should have names marked clearly
        $found_marked_name = "truthiness!" if $_ =~ $patterns{program_marked};

        # If we see STATISTICS before then, there are no marks
        last if $_ =~ /STATISTICS/;
    }
    close($fh);
    return $found_marked_name;
}

sub test_data_format {
    my ( $data_regex, $file ) = @_;
    my $without_outliers = '';
    open( my $fh, '<', $file );
    while (<$fh>) {
        next if /^\s*$/;
        if ( $_ =~ /$data_regex$patterns{without_outliers}/ ) {

            # Then there was an outlier free entry for "data"
            $without_outliers = "none of em!";
            last;
        }
        if ( $_ =~ /$data_regex$patterns{with_outliers}/ ) {

            # Then there is no outlier free entry for "data"
            last;
        }
    }
    close($fh);
    return $without_outliers;
}

sub adapt_format {
    $patterns{name} =
      test_name_format( $ARGV[0] )
      ? $patterns{program_marked}
      : $patterns{program_unmarked};

    for my $datum qw( mean stddev confidence ) {
        $patterns{$datum} =
          test_data_format( $patterns{$datum}, $ARGV[0] )
          ? qr/$patterns{$datum}$patterns{without_outliers}/
          : qr/$patterns{$datum}$patterns{with_outliers}/;
    }
}

sub dump_entry {
    my %en = @_;

    # Get rid of newlines
    chomp( $en{$_} ) for keys %en;

    # Convert from strings to numbers to unify formatting and to trim
    # excess whitespace
    my @row;
    for my $val ( @en{@data_list} ) {
        if ( looks_like_number($val) ) {
            $val = 0 + $val;
        }
        push @row, $val;
    }
    print join( ",", @row ), "\n";
}

adapt_format();

my %entry;
open( my $ifh, "<", $ARGV[0] );
LINE: while (<$ifh>) {
    next if /^\s*$/;

    my ($match) = $_ =~ $patterns{iterations};
    if ($match) {
        dump_entry(%entry) if %entry;
        %entry = ();
        $entry{iterations} = $match;
    }
    for my $key (@data_list) {
        my ($match) = $_ =~ $patterns{$key};
        $entry{$key} = $match and next LINE if $match;
    }
}
close($ifh);

# Catch trailing entry
dump_entry(%entry) if %entry;

__END__

=head1 NAME

libmicrotocsv.pl - Run on libMicro output to convert to csv (printed to STDOUT).

=head1 SYNOPSIS

B<libmicrotocsv.pl> file...

      -h --help                  Print this help documentation
      --data [name1[,name2...]]  Read and order data as specified

=head1 DESCRIPTION

This script parses libMicro output. It would be a lot simpler if it
just needed to do some regex ninja action, but instead libMicro seems
to have very different output depending on the options you give it.

I<INSTEAD> this script does a lookahead to see if the file is as it
expects, then adjusts its parsing accordingly. This isn't garunteed to
handle all sitations, please issues you see to me!


=head2 DATA SPECS

This program also includes the option of specifying the data to read
and in what order it should be printed (Name of the benchmark will
always be the first entry in a row).

    Key           Meaning
    ---------------------------------
    mean          The estimated mean
    stddev        Standard deviation
    confidence    Confidence interval
    numsamples    Number of samples in the mean
    iterations    Number of inner loop iterations

=head1 AUTHOR

Jean-Christophe Petkovich, E<lt>me@jcpetkovich.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Jean-Christophe Petkovich

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=head1 BUGS

None reported... yet.

=cut
