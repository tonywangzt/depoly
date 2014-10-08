package rpm;
use File::Find;
use File::Path;
use File::Copy;
use Data::Dumper;

my @file_array;
sub new {
	my $home_dir		= $ENV{'HOME'};
	my $TOPDIR			= "${home_dir}/rpmbuild",
	my $self = {
		RPMS 	    => "RPMS",
		SRPMS		=> "SRPMS",
		SPECS		=> "SPECS",
		SOURCES		=> "SOURCES",
		BUILD		=> "BUILD",
		BUILDROOT	=> "BUILDIROOT",
	};
	
	File::Path::remove_tree("$TOPDIR" , {keep_root => 1,}) if -d $TOPDIR;
	mkdir("$TOPDIR" , 0755 ) ;
	for my $key (keys %$self) {
		$self->{$key}	= "$TOPDIR/$key";
		mkdir ("$self->{$key}", 0755 ) unless -d "$self->{$key}";

	}

	$self->{TOPDIR} = $TOPDIR;
	$self->{HOME_DIR} = $home_dir;
	return bless $self;
}

sub build {
	my ($rpm,$git_param) = @_;
	
	my $module 		 = $git_param->{module};
	my $new_tag		 = $git_param->{new_tag};


	my $rpmbuild_data =qq(
%define name $new_tag

NAME		: %{name}
Version 	: 1
Release		: 1
Summary		: %{name}-%{version}
License		: GPL
Group		: Applications/File


%description
	%{name}-%{version}



%files
%defattr(-,www,www,0755)
);



	open(spec,"> $rpm->{SPECS}/$module.spec") or die "$!";
	print spec  "$rpmbuild_data";
	
	##find 文件
	find(\&wantd,"$rpm->{BUILDROOT}");
	@file_array 		= 	map{ $_ =~ s/$rpm->{BUILDROOT}//g ; $_} @file_array;
	$" = "\n";
	print spec "@file_array";
	close spec;

	my $rpmmacros_file 	= "$rpm->{HOME_DIR}/.rpmmacros";
	open(rpmmacros,"> $rpmmacros_file") or die "$!";
	print rpmmacros "%_topdir $rpm->{TOPDIR}\n%buildroot %{_topdir}/BUILDROOT"	;
	close rpmmacros;
	
	my $rpmbuild_binary = '/usr/bin/rpmbuild';
	my $action = '-ba';
	
	my @result = readpipe("/usr/bin/rpmbuild -ba $rpm->{SPECS}/$module.spec") or die "$!"	;
	@file_array = ();
	find(\&wantd,"$rpm->{RPMS}");
	$rpm->{file} = shift @file_array;
	return $rpm;
}


sub repo {
	my ($rpm,$rpm_param) = @_; 
	my $repo_dc = $rpm_param->{repo_dc};
	mkdir($repo_dc ,0755 )  unless -d $repo_dc ;
	copy("$rpm->{file}","$repo_dc") or die "$!";
	chdir($repo_dc) or die "$!";
	my $createrepo='/usr/bin/createrepo';
	my @result = readpipe("$createrepo -p -d --update  .") or die "$!";
	return "@result";
	
}



sub wantd{
	push @file_array ,$File::Find::name  if -f ;
}


1;

