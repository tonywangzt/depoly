package base_require;

sub time {
	my $pkg=shift;
	my  ($sec,$min,$hour,$mday,$mon,$year) = (localtime)[0..5];
	$mon < 10 ? ( $mon="0". ($mon+1)) : ($mon+=1);
	$mday		= '0' . $mday   if $mday < 10;
	$hour		= '0' . $hour   if $hour < 10;
	$min		= '0'  . $min   if $min < 10;
	$sec		= '0'  . $sec   if $sec < 10;
	$year+=1900;
	
	my $self = {
		year	=>	$year,
		mon		=>	$mon,
		mday	=>	$mday,
		hour	=>	$hour,
		min		=>	$min,
		sec		=> 	$sec,
		today	=> 	"${year}${mon}${mday}",
		now		=>	"${year}${mon}${mday}${hour}${min}${sec}",
	};

	return bless $self;
}















1;
