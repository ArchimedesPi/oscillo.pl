use warnings;
use Getopt::Std;

getopt('xytGgwsf',\%opts);

# pcm file = $opts{f}

# samples per pixel x
$xscale = $opts{x} // 1200;

# quant levels per pixel y
$yscale = $opts{y} // 100;

# oversampling target rate
$targetrate = $opts{t} // 1_099_961;

# wave preamplification, dB
$ygain = $opts{G} // 0;

# brightness added by one sample
$gain   = $opts{g} // 6;

# img width
$w      = $opts{w} // 1000;

# skip amount of seconds
$skip_sec = $opts{s} // 0.05;

############

# turquoise tint
for (0..127)   { @{$gradient[$_]} = ($_/2, $_*1.5 ,$_*1.5); }
for (128..255) { @{$gradient[$_]} = (64+ ($_-128)*1.5, 192+($_-128)/2, 192+($_-128)/2); }

open(S,"sox \"".$opts{f}."\" -r $targetrate -b 16 -c 2 -t .raw -e signed - trim $skip_sec gain $ygain|");

$n=0;
while(not eof(S)) {
  read(S,$a,2);
  $a = -unpack("s",$a);

  # pixel position of this sample
  $x = $n/$xscale;
  $y = ($a+32768)/$yscale;

  # bilinear interpolation
  $xdec = $x-int($x);
  $ydec = $y-int($y);
  $pix[$x][$y]     += (1-$xdec) * (1-$ydec);
  $pix[$x+1][$y]   += ($xdec)   * (1-$ydec);
  $pix[$x][$y+1]   += (1-$xdec) * ($ydec);
  $pix[$x+1][$y+1] += ($xdec)   * ($ydec);

  last if ($n/$xscale > $w);
  read(S,$a,2);
  $n++;
}

close(S);

open(U,"|convert -depth 8 -size ".$w."x".int(65536/$yscale)." rgb:- osc.png");
for $y (0..65536/$yscale-1) {
  for $x (0..$w-1) {
    $p = ($pix[$x][$y] // 0) * $gain;
    $p = 255 if ($p > 255);
    if ($y == round(65536/$yscale/2)) {
      @a = @{$gradient[$p]};
      for (@a) { $_ += 64; $_ = 255 if ($_ > 255); }
      print U pack("CCC",@a);
    } else {
      print U pack("CCC",@{$gradient[$p]});
    }
  }
}
close(U);


sub round { int($_[0]+.5); }
