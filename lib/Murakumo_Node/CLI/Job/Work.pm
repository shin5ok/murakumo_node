use strict;
use warnings;

package Murakumo_Node::CLI::Job::Work;

use TheSchwartz::Worker;
use base q(TheSchwartz::Worker);
use Carp;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Request::Common qw( POST );

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo_Node::CLI::Utils;

our $VERSION = q(0.0.1);

our $class_dir_path = sprintf "%s::", __PACKAGE__;
our %works;
our $config = Murakumo_Node::CLI::Utils->new->config;
our $default_callback_uri = $config->{job_callback_uri};


BEGIN {
  { 
    no warnings 'redefine';
    use TheSchwartz::Job;
    my $org_job_completed = TheSchwartz::Job->can('completed');
    *TheSchwartz::Job::completed = sub {
      my ($self, @args) = @_;
      my $job_uuid     = $self->arg->{job_uuid};
      my $message      = @args > 0 ? $args[0] : "";
      my $callback_uri = $self->arg->{callback_uri};
      $callback_uri ||= $default_callback_uri;

      # my ($self, $job_uuid, $message, $callback_uri) = @_;
      # 第2引数の 1 は成功(job.result列)
      _end_of_job($job_uuid, 1, $message, $callback_uri);

      if ( exists $self->arg->{callback_func} ) {
        $self->arg->{callback_func}->();
      }
                   
      $org_job_completed->( @_ );

    };

    my $org_job_failed = TheSchwartz::Job->can('failed');
    *TheSchwartz::Job::failed = sub {
      my ($self, @args) = @_;
      my $job_uuid     = $self->arg->{job_uuid};
      my $message      = @args > 0 ? $args[0] : "";
      my $callback_uri = $self->arg->{callback_uri};
      $callback_uri ||= $default_callback_uri;

      # my ($self, $job_uuid, $message, $callback_uri) = @_;
      # 第2引数の 1 は失敗(job.result列)
      _end_of_job($job_uuid, 2, $message, $callback_uri);
      # original の failed() は $message, $exit_status が引数なので
      # $message だけ
      $org_job_failed->( @_ );
    };

  }

};

{
  no warnings;
  *work = \&work_simple;
}

our $global_func = sub {
  # sample function
  my ($args) = @_;
  no strict 'refs';
  my $to = $config->{test_to} || "root";
  open my $p, "| /usr/sbin/sendmail -t";
  print {$p} "Subject: $args->{subject}\n";
  print {$p} "To: $to\n";
  print {$p} "\n";
  print {$p} "$args->{message}\n";
  close $p;
};

# コールバックルーチン
sub _callback {
  my ($self, $func, $func_args) = @_;
  if (ref $func eq 'CODE') {
    return $func->( $func_args );
  } else {
    return $global_func->( $func_args );
  }
}

sub _end_of_job {

  my ($job_uuid, $result, $message, $callback_uri) = @_;

  warn "end_of_job argument : ", Dumper \@_;
  warn "end_of_job argument : ", join ",,", @_;
  warn "callback uri # ", $callback_uri if $callback_uri;

  if (! $job_uuid) {
    warn "job uuid is not found... end_of_job() is not working... end.";
    return 0;
  }

  $callback_uri ||= $default_callback_uri;

  if ($callback_uri) {

    my $www_ua = LWP::UserAgent->new; 
    my $param;

    no strict 'refs';
    $param->{message}  = $message || "";
    $param->{result}   = $result;
    $param->{job_uuid} = $job_uuid;

   my $request = POST qq/$callback_uri/, [$param];

    $www_ua->timeout(10);
    my $respones = $www_ua->request($request);

    require Murakumo_Node::CLI::Remote_JSON_API;
    my $api_result = Murakumo_Node::CLI::Remote_JSON_API->new($callback_uri)->json_post('', $param);
    return $api_result->{result};

  }
  return 0;
}

sub work_simple {
  my ($self, $job) = @_;
  our %works;
  our $class_dir_path;
  my $job_class_name = $job->arg->{_worker_class};
  my $worker_class = $class_dir_path . $job_class_name;
  warn "=========== goto >>> ${worker_class}::work =============";
  eval qq{ use $worker_class };
  goto \&{ $worker_class . "::work" };

}

1;
