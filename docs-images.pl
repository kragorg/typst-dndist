#!/usr/bin/env perl
#
# docs-images — regenerate the README screenshots in docs/.
#
# - The README shows one page of each layout, rendered from template/main.typ.
# - The template is the densest character, thus it exercises the most layout.
# - A visible layout change dates both images.
# - The page number and the resolution of each image live in @images below.
# - The card deck opens with the foldable placard, thus the core card is page 2.
# - The resolutions give 900x600 (a 6x4in card) and 850x1100 (a letter page).
# - Keep them: a regenerated image then differs only where the layout did.
# - Run this from the repo root; it writes into docs/ in the working tree.
#
# Usage: docs-images.pl

use strict;
use warnings;
use File::Temp qw(tempdir);

my @images = (
    {
        name   => "card-deck",
        layout => "card",
        page   => 2,
        dpi    => 150,
    },
    {
        name   => "letter-sheet",
        layout => "letter",
        page   => 1,
        dpi    => 100,
    },
);

# - `nix run` keeps the caller's directory, thus the paths below are relative.
# - Both must exist, else this would render the wrong tree or write nowhere.
for my $need ( "template/main.typ", "docs" ) {
    -e $need or die <<"END_MSG";
docs-images: no $need here.

  Run this from the repo root: nix run .#docs-images
END_MSG
}

sub run {
    my @cmd = @_;
    system { $cmd[0] } @cmd;
    return if $? == 0;
    my $how = $? & 127 ? "signal " . ( $? & 127 ) : "exit " . ( $? >> 8 );
    die "docs-images: '$cmd[0]' failed ($how)\n";
}

my $tmp = tempdir( CLEANUP => 1 );

# - One render per layout, shared by every image that samples a page of it.
# - The layouts come from @images, thus a new image needs no second list here.
my %pdf = map { $_->{layout} => "$tmp/template-$_->{layout}.pdf" } @images;
for my $layout ( sort keys %pdf ) {
    print "rendering template ($layout)\n";
    run( "typst-strict", "--root", "template", "--input", "layout=$layout",
        "template/main.typ", $pdf{$layout} );
}

# `-singlefile` drops the page-number suffix, thus the name stays docs/<name>.png.
for my $image (@images) {
    my $out = "docs/$image->{name}";
    print "writing $out.png (page $image->{page} at $image->{dpi} dpi)\n";
    run(
        "pdftoppm", "-png",
        "-r", $image->{dpi},
        "-f", $image->{page},
        "-l", $image->{page},
        "-singlefile", $pdf{ $image->{layout} }, $out
    );
}
