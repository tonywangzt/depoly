package puppet;
use Data::Dumper;
use YAML::Syck;
use Data::Compare;

sub action {
	my ($rpm_param,$git_param,$puppet_param) = @_;
	
	my $puppet_dir 							 = $puppet_param->{config_dir};
	my ( $depoly_host_1,$depoly_host_2 )	 = @{$git_param->{depoly_host}};

	
	my $new_tag								 = $git_param->{new_tag};	
	my $web_root							 = $rpm_param->{webroot};
	my $rpm_prefix  						 = $rpm_param->{prefix};


	my $puppet_information = qq(Package {
	allow_virtual => false,
}

node "$depoly_host_1"{
		yumrepo { "depoly":
			enabled		=> '1',
			baseurl		=> 'http://puppetmaster.mylinuxsa.com/repo',
			gpgcheck	=> '0',
			before		=> Package["$new_tag"],
	
}
		package { "$new_tag":	
			ensure		=> installed ,
			allow_virtual	=> false,
			before 		=> File["$web_root"],
			notify		=> File["$web_root"],
	}	
		file { "$web_root":
			ensure	=> link,
			target	=> "$rpm_prefix/$new_tag",
			require	=> Package["$new_tag"],
	}
	
}
);
	
	defined $depoly_host_2 ? ( $puppet_information .= qq( node "production" inherirts test { }) )
			: ( $puppet_information .= qq(node "production" {} ) );


	open( F, "> $puppet_dir/manifests/depoly.pp")	or die "$!";
	print F $puppet_information;
	close F;
	
};

my $search_mco_puppet_hosts = sub {
	my @mco_puppet_hosts	;
	my $pid 			= $$;
	my $search_log 		= "/tmp/search.$$";
	my $command 		= "mco puppet status > $search_log";
	readpipe( $command ) ;
	open my $fh , "< $search_log" or die "$!";
	while ( <$fh> ){
		push	@mco_puppet_hosts , $1				if /^\s+((\w+\.){2}\w+)\:/;
	}
	close $fh;
	return @mco_puppet_hosts;
};


my  $puppet_report_file = sub {
	my ( $puppet_param,$self,$git_param )  = @_ ;
	my $puppet_report_dir	  = "$puppet_param->{report_dir}";
	chdir($puppet_report_dir) or die "$!";
	my @report_host			  = 
			( @{$self->{mco_puppet_hosts}} ? @{$self->{mco_puppet_hosts}} : glob("*") );
	
	$self					= {};
	
	@report_host			= ();
	
	for my $host ( @{$git_param->{depoly_host}} ){
		( ref $puppet_param->{$host} ) eq 'ARRAY' ?  map { push @report_host, $_  } @{$puppet_param->{$host}}
					 : push @report_host ,$puppet_param->{$host};
	}
	
	for my $host ( @report_host ) {
		opendir (my $dh, "$puppet_report_dir/$host" ) or die "$!";
		$self->{$host}    	  =   ( sort{  $b <=>  $a  } grep { $_ !~ /^\./ }readdir $dh )[0];
		close $dh;
	}
	
	die Dumper($self);
	return $self;
};

my $mco_puppet_command = sub {
	my $self					= {};
	my $pid 					= $$;
	my $mco_command_log 		= "/tmp/$pid";
	my $command = "mco puppet -v runonce > $mco_command_log";
	readpipe( $command ) ;
	sleep(5);
	open (my $dh, "< $mco_command_log") or die "$!";
	while(<$dh>){
		if (/^((?:\w+\.?){1,3})\s+\:\s+(\w+)$/){
		my $host				= $1;
		my $mco_command_status	= $2;
		$self->{$host} = $mco_command_status;
		}
	}
	close  $dh;
	unlink $mco_command_log ;
	return $self;

};


my $yaml_split = sub {
	my ( $puppet_param,$new_report ) = @_;
	my $self 						 = {}; 
	for my $host ( keys %${new_report} ) {
		my $host_yaml	= "$puppet_param->{report_dir}/$host/$new_report->{$host}"; 
		my $yaml 		= YAML::Syck::LoadFile( $host_yaml );
		my $event		= $yaml->{metrics}->{events}->{values};
		my @num 		= grep  { $event->[$_]->[0] =~ /failure/    } 0..2 ;
		my $num			= shift @num;
		my $failure		= $event->[$num]->[2];			
		$self->{$host}	= $failure;
	}
	return $self;
};


sub report {
		my ( $puppet_param,$git_param ) = @_ ;
	 	my $self 				  	 = {};
		@{$self->{mco_puppet_hosts}} = $search_mco_puppet_hosts->();
		for my $host ( @{$git_param->{depoly_host}} ){
			( ref $puppet_param->{$host} ) eq 'ARRAY' ?  map { push @report_host, $_  } @{$puppet_param->{$host}}
						 : push @report_host ,$puppet_param->{$host};
		}
		
		


		$self->{report}  		 	 = $puppet_report_file->($puppet_param,$self,$git_param);
		$self->{mco_status}	      	 = $mco_puppet_command->();

		$self->{new_report}			 = $puppet_report_file->($puppet_param,$self,$git_param);	
	

	
		$self->{yaml} =  $yaml_split->( $puppet_param,$new_report ) if $new_report;
		return $self;

};
1;
