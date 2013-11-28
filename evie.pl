#!/usr/bin/env perl

use warnings;
use strict;
use 5.010;
use Switch;

use Getopt::Long;
use Data::Dumper;
use File::Basename;
use Image::Magick;

no warnings qw{qw};

Getopt::Long::Configure ("bundling");


my $eda = '';
my $tmpdir = '/tmp/evietest/';
my $outdir = '/tmp/evietest/out/';

my %colors = (
    silk    => 'rgba(255,255,255,0.9)',
    stop    => 'rgba(000,150,000,0.85)',
    copper  => 'rgba(255,255,205,1)',
    finish  => 'rgba(205,205,255,0.9)', # copper without stop, eg ENIG gold
    base    => 'rgba(150,165,122,0.9)'
);

GetOptions (
    'eda|e=s' => \$eda,
    'out|o=s' => \$outdir
) or die "Error in command line arguments\n";

if (! defined $ARGV[0]) {
    die "no file given\n";
} elsif (! -f $ARGV[0]) {
    die "invalid file '$ARGV[0]' given\n";
}

my $brd = $ARGV[0];
my $brdout = "";

switch ($eda) {
    case (/^$/) {
        die "no eda given\n";
    }
    case (/eagle/i) {
        $brdout = exportEagle();
    }
    else {
        die "given eda '$eda' not supported\n";
    }
}

my $image = Image::Magick->new;
my @origexts = qw/GTL GBL GTS GBS GTO GBO GKO XLD XLN/;
my @gerbvopts = qw/gerbv -B 0 -O 0x0 -D 300 -b #000000 -f #ffffffff -x png /;

# convert gerber to png, find max. size
system( @gerbvopts, "-o", "$brdout.ALL.png", map( "$brdout.$_", @origexts ) );
$image->Read( "$brdout.ALL.png" );
my $max_rows = $image->Get( 'rows' )+5;
my $max_cols = $image->Get( 'columns' )+5;
@$image = ();
undef $image;

# ./evie.pl -e eagle /home/mo/projects/eagle/projects/tinyusbmk2/mkii.brd

foreach ( @origexts ) {
    system(@gerbvopts,  "-w", $max_cols."x".$max_rows, "-o", "$brdout.$_.png", "$brdout.$_");
}

# my $image = Image::Magick->new;
my $img_dmnsn = Image::Magick->new;
my $img_drill = Image::Magick->new;
my $img_holes = Image::Magick->new;

$img_dmnsn->Read( "$brdout.GKO.png" );
$img_drill->Read( "$brdout.XLD.png" );
$img_holes->Read( "$brdout.XLN.png" );

# transparent drills
$img_drill->Transparent( color=>'white', invert=>1);
$img_drill->Write( "$brdout.MOD.XLD.png" );

# holes (no plating)
$img_holes->Transparent( color=>'white', invert=>1);
$img_holes->Opaque( color=>'white', fill=>'black', channel=>'All');
$img_holes->Write( "$brdout.MOD.XLN.png" );

# dimension and holes
$img_dmnsn->Opaque( color=>'black', fill=>'red', channel=>'All');

# cover up holes
$img_dmnsn->Composite(image=>$img_holes, compose=>'SrcOver',gravity=>'SouthWest' ); 
# temporary border, don't hit the pcb itself, but remove afterwards
$img_dmnsn->Border(  geometry=>"10x10", fill=>'red' );
$img_dmnsn->ColorFloodfill( geometry=>"0x0", fill=>"black" );
$img_dmnsn->Crop( width => $max_cols, height => $max_rows , x => 10, y => 10);
$img_dmnsn->Opaque( color=>'white', fill=>'red', channel=>'All');


my $img_mask = $img_dmnsn->Clone();
$img_dmnsn->Opaque( color=>'red', fill=>$colors{base}, channel=>'All');
$img_dmnsn->Write( "$brdout.MOD.GKO.png" );
# base pcb ready!

# mask for everything
$img_mask->Transparent( color=>'red', invert=>0);
$img_mask->Write( "$brdout.mask.png" );

# drills
imgCutMaskColorize( $img_drill, $img_mask, 'black');
$img_drill->Write( "$brdout.MOD.XLD.png" );

my $img_stop_top = Image::Magick->new;
$img_stop_top->Read( "$brdout.GTS.png" );
imgCutMaskColorize( $img_stop_top, $img_mask, $colors{stop}, 1);
$img_stop_top->Write( "$brdout.MOD.GTS.png" );

my $img_copper_top = Image::Magick->new;
$img_copper_top->Read( "$brdout.GTL.png" );
imgCutMaskColorize( $img_copper_top, $img_mask, $colors{copper} );
$img_copper_top->Write( "$brdout.MOD.GTL.png" );

my $img_silk_top = Image::Magick->new;
$img_silk_top->Read( "$brdout.GTO.png" );
imgCutMaskColorize( $img_silk_top, $img_mask, $colors{silk} );
$img_silk_top->Write( "$brdout.MOD.GTO.png" );

sub imgCutMaskColorize {
    my ($workimage, $maskimage, $color, $invert) = @_;
    my ( $pos, $neg ) = ( 'black', 'white' );
    if ( $invert ) {
        ( $pos, $neg ) = ( 'white', 'black' );
    }
    $workimage->Transparent( color=>$pos, invert=>0);
    $workimage->Opaque( color=>$neg, fill=>$color, channel=>'All');
    $workimage->Composite(image=>$maskimage, compose=>'SrcOver' ); 
}

my $img_top = $img_dmnsn->Clone();
$img_top->Composite(image=>$img_copper_top, compose=>'SrcOver' );
$img_top->Composite(image=>$img_stop_top, compose=>'SrcOver' );
$img_top->Composite(image=>$img_silk_top, compose=>'SrcOver' );
$img_top->Composite(image=>$img_drill, compose=>'SrcOver' );
$img_top->Trim();
$img_top->Border(  geometry=>"10x10", fill=>'black' );
$img_top->Write( "$brdout.TOP.png" );

#image=>image-handle, compose=>{Undefined, Add, Atop, Blend, Bumpmap, Clear, ColorBurn, ColorDodge, Colorize, CopyBlack, CopyBlue, CopyCMYK, Cyan, CopyGreen, Copy, CopyMagenta, CopyOpacity, CopyRed, RGB, CopyYellow, Darken, Dst, Difference, Displace, Dissolve, DstAtop, DstIn, DstOut, DstOver, Dst, Exclusion, HardLight, Hue, In, Lighten, Luminize, Minus, Modulate, Multiply, None, Out, Overlay, Over, Plus, ReplaceCompositeOp, Saturate, Screen, SoftLight, Src, SrcAtop, SrcIn, SrcOut, SrcOver, Src, Subtract, Threshold, Xor }, mask=>image-handle, geometry=>geometry, x=>integer, y=>integer, gravity=>{NorthWest, North, NorthEast, West, Center, East, SouthWest, South, SouthEast}, opacity=>integer, tile=>{True, False}, rotate=>double, color=>color name, blend=>geometry, interpolate=>{undefined, average, bicubic, bilinear, filter, integer, mesh, nearest-neighbor, spline}

sub exportEagle {
    my ($brdname,$brdpath,$brdsuffix) = fileparse($brd, '.brd' );
    my $brdout = $tmpdir . "/" . $brdname;

    my @eaglecmd = ( $eda, '-C', ' ', '-N', '-X', $brd, '-c+' );
=cut
    my @exports = ( 
        ['-d', 'GERBER_RS274X', '-o ', "$brdout.GTL", qw/Top Pads Vias/] , 
        ['-d', 'GERBER_RS274X', '-o ', "$brdout.GBL", qw/Bottom Pads Vias/] , 
        ['-d', 'GERBER_RS274X', '-o ', "$brdout.GTS", qw/tStop/] , 
        ['-d', 'GERBER_RS274X', '-o ', "$brdout.GBS", qw/bStop/] , 
        ['-d', 'GERBER_RS274X', '-o ', "$brdout.GTO", qw/tPlace tNames/] , 
        ['-d', 'GERBER_RS274X', '-o ', "$brdout.GBO", qw/bPlace bNames/] , 
        ['-d', 'GERBER_RS274X', '-o ', "$brdout.GKO", qw/Dimension/] , 
        ['-d', 'EXCELLON', '-f-', '-o', "$brdout.XLD", qw/Drills/] , 
        ['-d', 'EXCELLON', '-f-', '-o', "$brdout.XLN", qw/Holes Milling/] , 
    );
    foreach (@exports) {
        my @cmd  = (@eaglecmd, @{$_} );
        say( join(" ", "cmd: ", @cmd) );
        system( @cmd );
    }
=cut
    return $brdout;
}

# ${EAGLE} -X -dGERBER_RS274X -o${outputfile}.cmp ${board} Top Pads Vias
# ${EAGLE} -X -dGERBER_RS274X -o${outputfile}.sol ${board} Bottom Pads Vias
# ${EAGLE} -X -dGERBER_RS274X -o${outputfile}.stc ${board} tStop
# ${EAGLE} -X -dGERBER_RS274X -o${outputfile}.sts ${board} bStop
# ${EAGLE} -X -dGERBER_RS274X -o${outputfile}.plc ${board} Dimension tPlace

# -Axxx Bestückungsvariante
# -Cxxx den angegebenen Befehl ausführen
# -Dxxx Draw-Toleranz (0.1 = 10%)
# -Exxx Drill-Toleranz (0.1 = 10%)
# -Fxxx Flash-Toleranz (0.1 = 10%)
# -N-   keine Rückfragen in der Kommandozeile
# -O+   Stift-Bewegungen optimieren
# -Pxxx Plotter-Stift (Layer=Stift)
# -Rxxx Bohrer-Datei
# -Sxxx Script-Datei
# -Uxxx Datei für Benutzereinstellungen
# -Wxxx Blenden-Datei
# -X-   CAM-Prozessor ausführen
# -c+   positive Koordinaten
# -dxxx Ausgabegerät (-d? für Liste)
# -e-   Blenden emulieren
# -f+   Pads ausfüllen
# -hxxx Seitenhöhe (inch)
# -m-   Ausgabe spiegeln
# -oxxx Ausgabedateiname
# -pxxx Stiftdurchmesser (mm)
# -q-   Quick-Plot
# -r-   Ausgabe um 90 Grad drehen
# -sxxx Skalierungsfaktor
# -u-   Ausgabe auf dem Kopf stehend
# -vxxx Stiftgeschwindigkeit
# -wxxx Seitenbreite (inch)
# -xxxx X-Versatz (inch)
# -yxxx Y-Versatz (inch)

