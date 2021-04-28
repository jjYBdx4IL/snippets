#!/usr/bin/perl
# vim:set sw=2 ts=2 et ai smartindent fileformat=unix fileencoding=utf-8 syntax=perl:

=pod

=head1 Synopsis

Put a passive check submission into the spool dir:

  submit_passive_nagios_result.pl <service-name> <service-status:0|1|2> [message]

Process the spool dir and submit all queued submissions (omit any args):
      
  submit_passive_nagios_result.pl

You can also define the I<service status> argument like

  rc:$n

. The script will then take the $n and normalize it to 0 (if rc:0, ie. $n == 0)
or to 2 if $n is not 0. That way you can simply funnal the exit code of the previous
command into this script and let it report on that (when running in a shell like BASH):

  some_check
  submit_passive_nagios_result.pl ExampleService rc:$?

Or, if you expect a non-zero exit code:

  some_check
  [[ $? != 0 ]]
  submit_passive_nagios_result.pl ExampleService rc:$?

Or, if you expect a specific exit-code, ie. 123:

  some_check
  [[ $? == 123 ]]
  submit_passive_nagios_result.pl ExampleService rc:$?

If there is an issue with the spool processing, ie. submission to nagios' cmd.cgi
script, the script will terminate with a non-zero status code and write an error
message to STDOUT (which should trigger an email if run by the usual cron daemon);

By default, the hostname command is used to determine the hostname used for submission.
This can be changed with:

  FORCE_HOST=somehost submit_passive_nagios_result.pl

You can also set the env variable I<TRACE> to 1 to enable more output to STDERR.

=head1 Spool directory setup

The configuration is only needed for submitting results to the server's cmd.cgi.
Make sure that users have write access to /var/spool/nagiosresdump, for example:

  mkdir /var/spool/nagiosresdump
  chmod 770 /var/spool/nagiosresdump
  groupadd nagiosresdump
  chown root.nagiosresdump /var/spool/nagiosresdump
  chmod g+s nagiosresdump
  adduser someuser nagiosresdump

=head1 Nagios configuration hints

  define command {
    ;Command changes a stale host from OK to WARNING
    command_name    stale_check
    command_line    /usr/local/nagios/libexec/check_dummy 2 "CRITICAL: Stale Result"
  }
  define command {
    ;Command always returns true. Useful for keeping host status OK. (needed?)
    command_name    check_null
    command_line    /bin/true
  }
  define host {
    ;template
    use                    generic-host
    name                   passive-host
    active_checks_enabled  0
    passive_checks_enabled 1
    contact_groups         admins
    max_check_attempts     1
  }
  define service {
    ;template
    name            passive-service
    use             generic-service
    register        0
    ; applies when running out of freshness
    check_interval             1
    check_command              stale_check
    max_check_attempts         1
    initial_state              o
    contact_groups             admins
    active_checks_enabled      0
    passive_checks_enabled     1
    check_freshness            1
    freshness_threshold        100800 ; 28 Hours (28 * 60 * 60)
    flap_detection_enabled     0
    check_interval             10
    notification_period        24x7
    ; Only notify once when service is marked as stale
    notification_interval      0
  }
  define host {
    use                    passive-host
    host_name              somehost
    alias                  SomeHost
    ; not used
    address                somehost.somedomain.com
    active_checks_enabled  0
    passive_checks_enabled 1
    contact_groups         admins
    max_check_attempts     1
  }
  define service{
    use                        passive-service
    host_name                  somehost
    service_description        ExampleTask
  }

=cut

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;
use URI;
use File::Slurp;
use FindBin;
use File::Path qw(make_path);
use JSON;

my ( $service, $state, $msg ) = @ARGV;
my $trace = $ENV{TRACE};


my $spooldir = "/var/spool/nagiosresdump";
if (! -e $spooldir) {
  mkdir $spooldir, 0700 or die $!;
}
die "cannot write to $spooldir" unless -d $spooldir;
die "cannot write to $spooldir" unless -w $spooldir;

my $host = $ENV{FORCE_HOSTNAME} ? $ENV{FORCE_HOSTNAME} : `hostname`;
$host = $ENV{FORCE_HOST} if $ENV{FORCE_HOST};
die if $?;
chomp($host);
die unless $host;


cronmode() unless $service;



$service =~ s/[^a-zA-Z0-9_-]/_/g;

if(!defined $state) {
    $state = 2;
    $msg = 'no state';
}
elsif($state =~ /^rc:(\d+)$/i) {
    $state = $1 ? 2 : 0;
}
elsif($state !~ /^[01234]$/) { # 4 => query last status report contents
    $state = 2;
    $msg = 'bad state';
}

if(!defined $msg) {
    $msg = 'n/a';
}

write_json($spooldir . "/" . time() . ".", {
    service => $service,
    state => $state,
    msg => $msg
}, appendmd5 => 1);

exit 0;

sub read_json {
    my ($fn) = @_;
    my $json = read_file($fn, binmode => ':raw');
    return from_json($json, {utf8 => 1});
}

sub write_json {
    my ($fn, $href, %opts) = @_;
    my $json = to_json($href, {utf8 => 1, pretty => 1});
    $fn .= md5_hex($json) if defined $opts{'appendmd5'};
    write_file($fn, $json);
}

my $cfg = {
    cmdcgiurl => 'https://nagiosadmin@localhost/nagios/cgi-bin/cmd.cgi',
    uninitialized => 1,
};

sub cronmode {
    print STDERR "cronmode()\n" if $trace;

    my $cfgdir = $ENV{HOME}."/.local/".$FindBin::RealScript;
    $cfgdir =~ s/\.pl$//i;
    make_path($cfgdir) unless -e $cfgdir;
    die unless -d $cfgdir;

    my $cfgfile = "$cfgdir/config.json";
    write_json($cfgfile, $cfg) unless -e $cfgfile;
    $cfg = read_json($cfgfile);
    die "Please edit $cfgfile and set the password in $ENV{HOME}/.netrc" if $cfg->{'uninitialized'};

    my $nerrs = 0;

    for my $spoolfile ( sort { -M $b <=> -M $a } read_dir($spooldir, prefix => 1) ) {
        print STDERR "spool file=$spoolfile\n" if $trace;
        my $data = read_json($spoolfile);
        if (submit($data)) {
            unlink $spoolfile;
        } else {
            $nerrs++;
        }
    }

    if ($nerrs != 0) {
        print "Failed to submit nagios passive check result.\n";
        exit 1;
    }
    exit 0;
}

sub submit {
    my ($dd) = @_;
    my $u = URI->new($cfg->{'cmdcgiurl'});
    my $msg = $dd->{'msg'} eq "" ? "null" : $dd->{'msg'};
    $msg =~ s/[\r\n\t]+/ /g;
    if (length($msg) > 768) {
	    $msg = substr($msg, 0, 768);
    }
    $u->query_form({
        'cmd_typ' => 30,
        'cmd_mod' => 2,
        'host'    => $host,
        'service' => $dd->{'service'},
        'plugin_state'  => $dd->{'state'} ne "4" ? $dd->{'state'} : "",
        'plugin_output' => $msg,
        'performance_data' => "",
        'btnSubmit'     => "Commit",
    });
    my $url = $u->canonical;

    my $success_msg = 'Your command request was successfully submitted to Nagios for processing.';
    print STDERR "url=$url\n" if $trace;
    my $pid = open(my $fh, "-|", 'wget', '-q', '-O', '-', $url) or die $!; # '--no-check-certificate'
    my $output = "";
    while (<$fh>) { $output .= $_; }
    my $pipeok = close $fh;
    if (!$pipeok) {
        print STDERR "rc=$?" if ($trace && $! == 0);
        return 0;
    }
    if ($output !~ /$success_msg/i) {
        print STDERR "cmd.cgi response: $output\n" if $trace;
        return 0;
    }
    return 1;
}
