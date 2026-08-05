#!/usr/bin/env perl
#
# typst-strict — `typst compile` that does not substitute a font quietly.
#
# - The sheet is calibrated to ETBembo, Montserrat, and Euler Math.
# - Bold numbers and small caps are synthesized against these faces.
# - Column widths and card-overflow decisions follow ETBembo's metrics.
# - A substituted font gives a correct-looking but wrong sheet.
# - This is the worst type of failure, because nothing looks broken.
# - This script adds `--ignore-system-fonts`, thus no caller must remember it.
# - That flag stops a system font from satisfying a family.
# - Typst still falls back to its embedded fonts.
# - Typst only gives a warning ("unknown font family: etbembo") and exits 0.
# - No CLI flag makes that warning an error, thus this wrapper does it.
# - Run the compile, pass its output through, and fail if a family is unresolved.
#
# Usage: typst-strict.pl <any typst compile arguments>

use strict;
use warnings;

die "usage: $0 <typst compile arguments>\n" unless @ARGV;

my @cmd = ( "typst", "compile", "--ignore-system-fonts", @ARGV );

# - Fold stderr into stdout, thus warnings and errors keep their sequence.
# - Capture all of the output.
# - `open '-|'` forks. The child sends stderr to stdout and then execs.
# - Nothing goes through a shell, thus no argument needs quotes.
my $pid = open( my $fh, '-|' );
defined $pid or die "typst-strict: cannot fork: $!\n";
unless ($pid) {
    open( STDERR, '>&', \*STDOUT ) or die "typst-strict: cannot redirect stderr: $!\n";
    exec { $cmd[0] } @cmd
      or die "typst-strict: cannot exec '$cmd[0]': $!\n";
}

my $output = do { local $/; <$fh> } // '';
close $fh;
my $status = $?;

print STDERR $output if $output;

# Pass on a real compile failure unchanged: typst already reported the problem.
if ( $status != 0 ) {
    exit( $status >> 8 ) if $status >> 8;
    die "typst-strict: typst died with signal " . ( $status & 127 ) . "\n";
}

if ( $output =~ /unknown font family/ ) {
    print STDERR <<'END_MSG';

typst-strict: refusing to emit a sheet with substituted fonts.

  A required font family could not be resolved (see the warnings above). The
  layout is calibrated to ETBembo, Montserrat, and Euler Math; substituting any
  of them produces a subtly incorrect sheet rather than an obviously broken one.

  Fix: build through the flake (nix develop / nix flake check), which supplies
  all three fonts. Outside Nix, point TYPST_FONT_PATHS at a directory holding
  ETBembo, Montserrat, and Euler Math.
END_MSG
    exit 1;
}
