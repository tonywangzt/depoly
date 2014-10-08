#!/usr/bin/perl
use 5.010;
use Dancer;
set warnings => 0;

use myapp;
use base_require;
use puppet;
use rpm;
use Data::Dumper;
use git;


#############param####################
my $modules	 = ['caijing','phpcms'];

my $db_param = {
	name	=> 'depoly',
	host	=> 'localhost',
	user	=> 'depoly',
	pass	=> '123456',
}; 

my $auth		= {	user => 'tony',	pass => '123456',};

my $rpm_param 	= { prefix => '/var/www', webroot => '/var/www/html', repo_dc => '/usr/share/nginx/html/repo',};

my $git_param 	= { git_dc => '/data/git', log_size => 5, };

my $puppet_param =  {
	report_dir	=> '/var/lib/puppet/reports',
	config_dir	=> '/etc/puppet',
	test		=> 'agent01.mylinuxsa.com',
	production	=> [ qw/agent02.mylinuxsa.com
						agent03.mylinuxsa.com
					/],
};


###################param##################
my $param	= {
	modules		=> $modules,
	db_param	=> $db_param,
	rpm_param	=> $rpm_param,
	git_param	=> $git_param,
	puppet_param=> $puppet_param,
	auth		=> $auth,
};

##################go#################
get '/login' => sub {
    template 'login';
};

post '/login' => sub{
	my $self	= $param;
	my $user	= $self->{auth}->{user};
	my $pass	= $self->{auth}->{pass};
	if (params->{username} eq $user && params->{password} eq $pass ){
		session user => params->{username};
		redirect '/git_list';
	}else {
		redirect '/login?failed=1';
	}
};

get '/git_list' => sub {
	my $git_param			= $param->{git_param} ;
	
	#指定具体的git 库，如果没有显示指定，就为所有git 库
	$git_param->{modules}	= $param->{modules};
	#如果定义了具体分支，则只查找指定分支，如果想查找分支，设置为all
	$git_param->{branch} 	= ['master'];

	$git_param->{log_size}	= 1;

	my $git = git->new($git_param);
#
	template 'git_list' ,{	
				git => $git,
	};
};

get '/depoly/:module' => sub {	
	my $git_param 			= $param->{git_param};
	$git_param->{log_size}  = 5;
	$git_param->{branch}	= ['all'];
	@{$git_param->{modules}} = my $git_module =  param('module');
	

	my $git = git->new($git_param);
	template 'module' ,{
		git => $git,
		git_module => $git_module,
	};
};

#any ['post','get'] => '/back/:module' => {
#	@{$git_param->{module}} = my $git_module =  param('module');
#};

any ['post','get'] => '/manage/depoly' => sub {
	my $git_param						= $param->{git_param};
	@{$git_param}{qw(commit branch)}	= (split/%/, param('commit'))[0,1];
	my $depoly_host				 		= param('host');
	@{$git_param->{depoly_host}} 		= 
			( (ref $depoly_host)  eq 'ARRAY'  ?  @{$depoly_host}  : ( $depoly_host )   ) ;	
	

	$git_param->{module}				=  param('module');
	$git_param->{log_size}				= 1;

	my $rpm 							= rpm->new();
	my $base_require					= base_require->time();
	my $git								= git->new();
	
	$git_param->{new_tag}				= $git->git_create_tag($base_require,$git_param);
	$git->git_clone($rpm,$git_param,$rpm_param);
	$rpm	 							= $rpm->build($git_param);
	my $repo_file						= $rpm->repo($rpm_param);
	puppet::action($rpm_param,$git_param,$puppet_param);


	my $depoly 							= puppet::report($puppet_param,$git_param);
	#template 'depoly' ,{
	#		depoly => $depoly,
	#};
};




start;

