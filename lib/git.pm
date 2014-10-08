package git;
use Git::Repository;
use File::Find;
use File::Path;
use Data::Dumper;



sub new {
	my ($pkg,$git_param) 	= @_;
	my $self				= {};
	return bless $self		unless  $git_param ;

	my @branch	= @{$git_param->{branch}}		 	 if defined $git_param->{branch};
	my @modules	= @{$git_param->{modules}}		 	 if defined $git_param->{modules};
	my $log_size = '-' . "$git_param->{log_size}"	 if defined $git_param->{log_size};


	for my $module ( @modules ) {
		$self->{$module}->{git_dir}	=  my $git_module_dir	= "$git_param->{git_dc}/$module";
		my $r				= Git::Repository->new( work_tree => $git_module_dir );
		
		( grep { $_ =~ /all/ }  @branch ) ?
				 ( @branch = map { (split /\s+/)[1] } $r->run( branch => '-l') ) : @branch ;
		
		for my $branch ( @branch ) {
			$r->run( checkout => $branch, {quiet => 1},);

			my @git_commit_logs = $r->run( log	=> $log_size ) or die "$!";
			my $log_num = $log_line = 1;
	
			for my $log ( @git_commit_logs ) {
				$log_line < 6 ? $log_line++ :( $log_line = 1 ,$log_num++ );
				my ($a,@b)  	= split( /\s+/, $log);
				$a				=~ s/^(.*):$/\1/;
				$a .= "notes"	if $log_line == 6;
				$self->{$module}->{$branch}->{$log_num}->{$a} = "@b";
			}
		}
	}
	return bless $self;
}

sub git_create_tag {

	my ($git,$base,$git_param)	= @_;
	my $module 					= $git_param->{module};
	my $branch					= $git_param->{branch};	
	my $commit					= $git_param->{commit};	
	
	my $r = Git::Repository->new(work_tree => "$git_param->{git_dc}/$module");
	$r->run( checkout => $branch );
	$r->run( reset => $commit );

	my $new_tag	= "$module-$branch-$base->{now}";

	$r->run( tag => $new_tag );

	return $new_tag;
}

sub git_clone {
	my ($git,$rpm,$git_param,$rpm_param) = @_;
	
	my $rpm_prefix	= $rpm_param->{prefix};

	my $branch 		= $git_param->{branch};
	my $new_tag		= $git_param->{new_tag};
	my $module		= $git_param->{module};

	File::Path::remove_tree("$rpm->{BUILDROOT}/" , {keep_root => 1,});
	Git::Repository->run( clone =>"$git_param->{git_dc}/$module", "$rpm->{BUILDROOT}/$rpm_prefix/$new_tag");
	my $r = Git::Repository->new(work_tree => "$rpm->{BUILDROOT}/$rpm_prefix/$new_tag");
	$r->run(checkout => $branch);
	$r->run(reset => $new_tag);
	File::Path::remove_tree("$rpm->{BUILDROOT}/$rpm_prefix/$new_tag/.git");
}
#
#sub git_show_tag {
#	my $self			= shift;
#	my $git_module_dir	= $self->{git_dc};
#	my $r = Git::Repository->new(work_tree => $git_module_dir);
#	$r->run(checkout => $branch);
#	my @tag_all = $r->run( git => '-l')	;
#	my @git_module_branch_tag = grep ( $_ =~ /$git_module_dir-$branch/,@tag_all);
#	@git_module_branch_tag =reverse @git_module_branch_tag;
#}
#
#sub git_merge_branch {
#	my $src_branch;
#	my $dst_branch;
#	my $r = Git::Repository->new(work_tree => $git_module_dir);
#	$r->run(checkout => $dst_branch);
#	$r->run(merge => $src_branch);	
#
#}
#
1;
