use strict;
use warnings;
use File::Path;
use Data::Dumper;

if ($> != 0) {
  warn "$0 is run by root";
  exit 255;
}

my %param = (
  admin_host => "",
  nfs_host => "",
  "nfs_export_path(for public share)" => "",
  "nfs_mount_path(for public share)" => "",
);

while (1) {
  print "admin_host > ";
  chomp ($param{admin_host} = <STDIN>);
  print "nfs share export host > ";
  chomp ($param{nfs_host} = <STDIN> );
  print "nfs share export path > ";
  chomp ($param{nfs_export_path} = <STDIN> );
  print "nfs share mount path > ";
  chomp ($param{nfs_mount_path} = <STDIN> );

  if (param_check()) {
    last;
  } else {
    print "param is invalid...next\n";
    next;
  }

}

{
  local $Data::Dumper::Terse = 1;
  warn Dumper \%param;
};

print "\n";
print " [ press any key for setup ]\n";
<STDIN>;

sub param_check {
  for my $v ( keys %param ) {
    $param{$v} or return 0;
  }
  return 1;

}


my @cmds = (
  \q{chkconfig NetworkManager --del},
  \q{chkconfig network on},
  \q{mkdir -p /root/.ssh},
  \q{chmod 700 /root/.ssh},
  \&ssh_make,
  \&conf_rewrite,
  \&murakumo_perl_create,
  \q{cd /home/smc/murakumo_node/bin; sh ./daemon-init-set.sh},
  \&sysctl_conf,
  \&rsyslog_conf,
  \q{rm -f /etc/libvirt/qemu/networks/autostart/default.xml},
  \q{/sbin/iptables -I INPUT -p tcp --dport 3000 -j ACCEPT},
  \q{/etc/init.d/iptables save},
  \q{mkdir -p /nfs},
  \q{mkdir -p /nfs/share},
  \&aliases,
  \q{newaliases},
  \&fstab,
  \&make_mount_path,
);

for (@cmds) {
  if (ref $_ eq 'SCALAR') {
    my $command = $$_;
    system qq[$command];
  }
  elsif (ref $_ eq 'CODE') {
    $_->(%param); 
  }
}

sub ssh_make {
  open my $v ,">", "/root/.ssh/config";
  print ${v} "
Host *
  StrictHostKeyChecking no
  UserKnownHostsFile=/dev/null
";
  close $v;
}

sub conf_rewrite {
  open my $v, "+<", "/home/smc/murakumo_node/murakumo_node.conf";
  flock $v, 2;

  seek $v, 0, 0;
  my $new = "";
  my $admin_host = $param{admin_host};
  while (<$v>) {
    if (/^job_callback_uri/) {
      $new .= "job_callback_uri http://$admin_host:3000/job/update/\n";
      next;
    }
    if (/^api_uri/) {
      $new .= "http://$admin_host:3000/\n";
      next;
    }
    if (/^callback_host\s+/)  {
      $new .= "callback_host $admin_host\n";
      next;
    }
    $new .= $_
  }

  seek $v, 0, 0;
  truncate $v, 0;

  print {$v} $new;


  close $v;

}

sub murakumo_perl_create {
  if (! -e "/usr/bin/murakumo-perl") {
    if (fork() == 0) {
      chdir "/usr/bin";
      symlink "/home/smc/bin/perl", "murakumo-perl";
    }
    
  }

}

sub sysctl_conf {
  open my $v, "+<", "/etc/sysctl.conf";
  flock $v, 2;
  seek $v, 0, 0;

  if (! grep { /^vm\.swappiness/ } <$v> ) {
    seek $v, 0, 2;

    print {$v} "vm.swappiness = 0\n";

  }

  close $v;

}

sub rsyslog_conf {
  open my $v, "+<", "/etc/rsyslog.conf";
  flock $v, 2;
  seek $v, 0, 0;

  my $new = "";
  my @orgs = <$v>;

  if (grep { m{^local0\..+/var/log/murakumo_node_api\.log} } @orgs) {
    return 1;
  }

  for (@orgs) {
    if (m|^(\S+)(\s+/var/log/messages)|) {
      $new .= $1 . ";local0.none" . $2 . "\n";
      next;
    }

    if (m|^local7|) {
      $new .= "local0.*    /var/log/murakumo_node_api.log\n";
    }
    $new .= $_;

  }

  seek $v, 0, 0;
  truncate $v, 0;

  print {$v} $new;

  close $v;

}

sub aliases {
  open my $v, "+<", "/etc/aliases";
  flock $v, 2;
  seek $v, 0, 0;

  if (! grep { /^murakumo\s*:/ } <$v> ) {
    seek $v, 0, 2;

    print {$v} qq#murakumo: "| /home/smc/murakumo_node/bin/post-api-by-mail.pl\n#;

  }

  close $v;

}

sub fstab {
  open my $v, "+<", "/etc/fstab";
  seek $v, 0, 0;
  if (! grep { m[^$param{admin_host}:/] } <$v> ) {
    seek $v, 0, 2;
    print {$v} "$param{admin_host}:$param{nfs_export_path}  $param{nfs_mount_path}     nfs  defaults,_netdev,nfsvers=3  0 0"."\n";

  }
  close $v;

}

sub make_mount_path {
  my %param = @_;
  system "mkdir -p $param{nfs_mount_path}";  
}

sub logrotate_syslog_modify {
  open my $v, "+<", "/etc/logrotate.d/syslog";
  seek $v, 0, 0;
  my @texts = <$v>;
  grep { m[/var/log/murakumo_node_api\.log] } @texts
    and return;

  my $new = "";
  for my $text ( @texts ) {
    if ($text =~ /^\s*}/) {
      $new .= "/var/log/murakumo_node_api.log\n"; 
      next;
    }
    if ($text =~ /^(\s*)sharedscript/) {
      $new .= "$1daily\n";
      $new .= "$1compress\n";
      next;

    }

    $new .= $text;
  }

  seek $v, 0, 0;
  truncate $v, 0;
  print {$v} $new;

  close $v;

}
