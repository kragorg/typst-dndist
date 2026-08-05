#!/usr/bin/env perl
#
# fonts — download the three font families the sheet is calibrated to.
#
# - The repository does not vendor fonts; this fetches them into ./fonts.
# - `TYPST_FONT_PATHS=$PWD/fonts` then completes a clone: typst needs nothing else.
# - Every file is pinned by sha256 to the exact build the Nix flake renders with.
# - A pinned hash is the point: a font family that resolves to a different build
#   gives a plausible-looking, subtly wrong sheet, and typst reports nothing.
# - The `font-pins` check compares these hashes against the flake's own fonts,
#   thus a nixpkgs bump fails the build instead of drifting silently.
#
# Usage:
#   perl fonts.pl              download what is missing into ./fonts
#   perl fonts.pl --check      verify ./fonts, and download nothing
#   perl fonts.pl --force      download again, even if the file is present
#   perl fonts.pl --dest DIR   use DIR instead of ./fonts
#   perl fonts.pl --pins       print the pinned hashes (the font-pins check)

use strict;
use warnings;

use Digest::SHA qw(sha256_hex);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Spec ();
use File::Temp qw(tempdir);
use Getopt::Long qw(GetOptions);

# - `et-book` ships its faces inside one archive; the others are single files.
# - The revisions match nixpkgs, thus every file below is byte-identical to the
#   font the flake renders with (verified by the `font-pins` check).
my $ET_REV  = '7e8f02dadcc23ba42b491b39e5bdf16e7b383031';
my $MO_TAG  = 'v9.000';
my $ET_TAR  = "https://github.com/edwardtufte/et-book/archive/$ET_REV.tar.gz";
my $MO_RAW  = "https://raw.githubusercontent.com/JulietaUla/montserrat/$MO_TAG";
my $EU_OTF  = 'https://mirrors.ctan.org/fonts/euler-math/Euler-Math.otf';

my @FONTS = (
    # - ETBembo — the body face. Only these five faces exist.
    # - Each `map` is parenthesized: a bare one swallows every entry after it.
    (
        map {
            {
                family => 'et-book',
                file   => "$_->[0].ttf",
                sha256 => $_->[1],
                member => "et-book-$ET_REV/source/4-ttf/$_->[0].ttf",
                tar    => $ET_TAR,
            }
        } (
            [ 'et-book-bold-line-figures', '98ac6c26068c6547c4b8e8a172803b706d90b5791d7fc5ee3306b9696a284dea' ],
            [ 'et-book-display-italic-old-style-figures', '377e9998015775b224727031045990926844011cf291343b9fc3cef97fd7abca' ],
            [ 'et-book-roman-line-figures', '7aa07ed5e482e2cc8ff44351e29d36f78e4d7fc63e534c68af3ff3484ea2b7e3' ],
            [ 'et-book-roman-old-style-figures', '842d93e0a16b405399100efadcca2a70b1909e812ef23d108c711b892cd385a6' ],
            [ 'et-book-semi-bold-old-style-figures', '6f86c938b836861d035dc645de249e163940132685a93c02f1a9e0c30fb9155e' ],
        )
    ),

    # Montserrat — labels and headings. The layout asks for these three weights
    # only, thus the other fifteen are not downloaded.
    (
        map {
            {
                family => 'montserrat',
                file   => "Montserrat-$_->[0].otf",
                sha256 => $_->[1],
                url    => "$MO_RAW/fonts/otf/Montserrat-$_->[0].otf",
            }
        } (
            [ 'Regular', 'c40080ac0d0a318d51b9242864c938f8e12df019285b6d9543c266c85eee1123' ],
            [ 'Medium',  '9e2bff7923aaf42c5db116a1811f35ff41aa978abf091aed97ab5e1d0f052669' ],
            [ 'Bold',    '7869c1657888d7d9ba60fa243a37ffbc6b0eb316b1a93044bb1e07ba6ec169a8' ],
        )
    ),

    # Euler Math — every digit and all math.
    {
        family => 'euler-math',
        file   => 'Euler-Math.otf',
        sha256 => 'd6faf2b5f507aab84990b5fb144675a57dbd6b2b3c216947b99fb1dc9b140529',
        url    => $EU_OTF,
    },
);

# - The licenses ride along with the fonts they cover, as both licenses require.
# - They carry no pinned hash: they are not rendered, thus a newer text is fine.
my @LICENSES = (
    {
        family => 'et-book',
        file   => 'LICENSE',
        member => "et-book-$ET_REV/LICENSE",
        tar    => $ET_TAR,
    },
    {
        family => 'montserrat',
        file   => 'OFL.txt',
        url    => "$MO_RAW/OFL.txt",
    },
    {
        family => 'euler-math',
        file   => 'OFL.txt',
        url    => 'https://raw.githubusercontent.com/khaledhosny/euler-otf/master/OFL.txt',
    },
);

my %opt;
GetOptions( \%opt, 'dest=s', 'check', 'force', 'pins', 'help' )
  or die "fonts: bad arguments (try --help)\n";

if ( $opt{help} ) {
    print <<'END_USAGE';
fonts.pl — download the fonts the dndist sheet is calibrated to.

  perl fonts.pl              download what is missing into ./fonts
  perl fonts.pl --check      verify ./fonts, and download nothing
  perl fonts.pl --force      download again, even if the file is present
  perl fonts.pl --dest DIR   use DIR instead of ./fonts
  perl fonts.pl --pins       print the pinned hashes
END_USAGE
    exit 0;
}

# The `font-pins` check reads this, thus the hashes are stated in one place.
if ( $opt{pins} ) {
    print "$_->{sha256}  $_->{file}\n" for @FONTS;
    exit 0;
}

my $dest = $opt{dest} || File::Spec->catdir( dirname( File::Spec->rel2abs($0) ), 'fonts' );

exit( check($dest) ) if $opt{check};

download($dest);
exit 0;

# - Report every file that is absent or altered.
# - Exit 1 when any is, thus a caller can gate on it.
sub check {
    my ($dir) = @_;
    my @bad;
    for my $f (@FONTS) {
        my $path = File::Spec->catfile( $dir, $f->{family}, $f->{file} );
        push( @bad, "$f->{file}: missing" ), next unless -f $path;
        my $got = sha256_hex( slurp($path) );
        push @bad, "$f->{file}: sha256 $got, expected $f->{sha256}"
          if $got ne $f->{sha256};
    }
    if (@bad) {
        print STDERR "fonts: $dir is not complete:\n";
        print STDERR "  $_\n" for @bad;
        print STDERR "  Fix: perl fonts.pl\n";
        return 1;
    }
    print "All " . scalar(@FONTS) . " font files present and verified in $dir\n";
    return 0;
}

sub download {
    my ($dir) = @_;
    my $tmp = tempdir( CLEANUP => 1 );
    my %tarball;    # An archive is fetched once, however many files it holds.
    my $fetched = 0;

    for my $f ( @FONTS, @LICENSES ) {
        my $path = File::Spec->catfile( $dir, $f->{family}, $f->{file} );
        if ( -f $path && !$opt{force} ) {
            next if !$f->{sha256} || sha256_hex( slurp($path) ) eq $f->{sha256};
        }
        make_path( dirname($path) );

        if ( $f->{tar} ) {
            my $archive = $tarball{ $f->{tar} } ||= fetch_tarball( $f->{tar}, $tmp );
            extract( $archive, $f->{member}, $path, $tmp );
        }
        else {
            fetch( $f->{url}, $path );
        }

        if ( $f->{sha256} ) {
            my $got = sha256_hex( slurp($path) );
            die "fonts: $f->{file} has sha256 $got, expected $f->{sha256}\n"
              . "  The upstream file changed. Do not use it: the layout is\n"
              . "  calibrated to the pinned build. Re-pin it deliberately.\n"
              if $got ne $f->{sha256};
        }
        print "  $f->{family}/$f->{file}\n";
        $fetched++;
    }

    print $fetched
      ? "\nDownloaded $fetched files into $dir\n"
      : "\nAlready complete: $dir\n";
    print <<"END_NEXT";

Point typst at them (add this to your shell rc to make it stick):
  export TYPST_FONT_PATHS="$dir"
END_NEXT
}

# - curl is the fetcher, with wget as the fallback.
# - macOS and every ordinary Linux carry one of the two.
sub fetch {
    my ( $url, $path ) = @_;
    print "fetching $url\n";
    my @cmd =
      have('curl')
      ? ( 'curl', '--fail', '--silent', '--show-error', '--location', '--output', $path, $url )
      : have('wget') ? ( 'wget', '--quiet', '--output-document', $path, $url )
      :                die "fonts: neither curl nor wget is on PATH\n";
    system { $cmd[0] } @cmd;
    die "fonts: cannot download $url\n" if $?;
}

sub fetch_tarball {
    my ( $url, $tmp ) = @_;
    my $path = File::Spec->catfile( $tmp, 'archive.tar.gz' );
    fetch( $url, $path );
    return $path;
}

# `tar` names one member, thus the other 2 MB of the archive is never written out.
sub extract {
    my ( $archive, $member, $path, $tmp ) = @_;
    my @cmd = ( 'tar', '-xzf', $archive, '-C', $tmp, $member );
    system { $cmd[0] } @cmd;
    die "fonts: cannot extract $member\n" if $?;
    rename( File::Spec->catfile( $tmp, $member ), $path )
      or die "fonts: cannot place $path: $!\n";
}

sub have {
    my ($cmd) = @_;
    for my $d ( File::Spec->path ) {
        return 1 if -x File::Spec->catfile( $d, $cmd );
    }
    return 0;
}

sub slurp {
    my ($path) = @_;
    open( my $fh, '<:raw', $path ) or die "fonts: cannot read $path: $!\n";
    return do { local $/; <$fh> };
}
