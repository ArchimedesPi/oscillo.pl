use Modern::Perl;
use Getopt::Std;

my %opts = ();
getopt('xytGgwsfo',\%opts);

# pcm file = $opts{f}
# output file = $opts{o}

# samples per pixel x
my $xscale = $opts{x} // 1200;

# quant levels per pixel y
my $yscale = $opts{y} // 100;

# oversampling target rate
my $targetrate = $opts{t} // 1_099_961;

# wave preamplification, dB
my $ygain = $opts{G} // 0;

# brightness added by one sample
my $gain   = $opts{g} // 6;

# img width
my $w      = $opts{w} // 1000;

# skip amount of seconds
my $skip_sec = $opts{s} // 0.05;

############

# turquoise tint
my @gradient;
for (0..127)   { @{$gradient[$_]} = ($_/2, $_*1.5 ,$_*1.5); }
for (128..255) { @{$gradient[$_]} = (64+ ($_-128)*1.5, 192+($_-128)/2, 192+($_-128)/2); }

open(S,"sox \"".$opts{f}."\" -r $targetrate -b 16 -c 2 -t .raw -e signed - trim $skip_sec gain $ygain|");

my $n=0;
my @pix;
while(not eof(S)) {
  read(S,$a,2);
  my $a = -unpack("s",$a);

  # pixel position of this sample
  my $x = $n/$xscale;
  my $y = ($a+32768)/$yscale;

  # bilinear interpolation
  my $xdec = $x-int($x);
  my $ydec = $y-int($y);
  $pix[$x][$y]     += (1-$xdec) * (1-$ydec);
  $pix[$x+1][$y]   += ($xdec)   * (1-$ydec);
  $pix[$x][$y+1]   += (1-$xdec) * ($ydec);
  $pix[$x+1][$y+1] += ($xdec)   * ($ydec);

  last if ($n/$xscale > $w);
  read(S,$a,2);
  $n++;
}

close(S);

open(image_file,"|convert -depth 8 -size ".$w."x".int(65536/$yscale)." rgb:- ".$opts{o});
for my $y (0..65536/$yscale-1) {
  for my $x (0..$w-1) {
    my $p = ($pix[$x][$y] // 0) * $gain;
    $p = 255 if ($p > 255);
    if ($y == round(65536/$yscale/2)) {
      my @a = @{$gradient[$p]};
      for (@a) { $_ += 64; $_ = 255 if ($_ > 255); }
      print image_file pack("CCC",@a);
    } else {
      print image_file pack("CCC",@{$gradient[$p]});
    }
  }
}
close(image_file);


sub round { int($_[0]+.5); }
