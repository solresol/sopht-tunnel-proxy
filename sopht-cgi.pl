#!/usr/bin/perl -w

use Socket;
use strict;
use CGI;
use FileHandle;
use IPC::Open2;
$|=1;
my $debugging = 1;

my $query = new CGI;
my $unixport = $query->param('unixport');
my $keystrokes = $query->param('keystrokes');
my $i_am_the_server = 0;

sub whinge {
  print "Content-type: text/plain\n\n";  print "$_[0]\n"; 
  exit 0;
}

if ($unixport !~ /^(\w+)$/) { &whinge("No.  No way."); }
else {  $unixport = $1;  }  # untainted now


my $rendezvous = "/tmp/.sopht-$unixport";
my $pid;

unless (-S $rendezvous) {
  # we need to start up the server.
  $pid = fork();
  if ($pid == 0) {    &the_server();   exit(0);    }
  sleep(1); # don't know if this is long enough, maybe I should get a kill?
}

unless (socket(SOCK, PF_UNIX, SOCK_STREAM, 0))  {  &whinge("socket: $!"); }
unless (connect(SOCK, sockaddr_un($rendezvous))) { &whinge("connect: $!"); }

my $line;
my @characters;
my $character;
my $data;
my $fh;

$fh=select(SOCK); $|=1; select ($fh);
print SOCK "$keystrokes";
print "Content-type: application/x-sopht\n\n";
while (<SOCK>) {
  chomp;
  $data = "";
  @characters = split;
  foreach $character (@characters) {
    $data .= chr ($character);
  }
  print "$data";
}
exit;

sub the_server {
  $i_am_the_server = 1;
  my $uaddr = sockaddr_un($rendezvous);
  socket(Server,PF_UNIX,SOCK_STREAM,0) || die "$0/server socket: $!";
  bind  (Server, $uaddr)               || die "$0/server bind: $!";
  listen(Server,SOMAXCONN)             || die "$0/listen: $!";

  $|=1;

  my $remote = 'localhost';
#  my $port = 23;  # for telnet
#  my $port = 22; # for ssh
  my $port = 80; # for http over http!
  my $iaddr = inet_aton($remote);
  my $paddr = sockaddr_in($port,$iaddr);
  my $proto = getprotobyname('tcp');
  socket(LOCALTCP, PF_INET, SOCK_STREAM, $proto)
     || die "telnet $remote $port: $!";
  connect(LOCALTCP,$paddr);

#  my $sshpid = open2(*Reader, *Writer, "sshd -i" );
#  my $sshpid = open2(*Reader, *Writer, "cat -u -n");

  # Can't do anything until we get a connection,
  # which should happen quite quickly

  accept(Client,Server);
  $fh=select(Client); $|=1; select ($fh);
  my ($rin,$win,$ein,$rout,$wout,$eout);
  my ($buffer);
  my ($translated_buffer);
  my ($character);
  my (@characters);
  my ($i);

  while (1) {
    $rin = $win = $ein = '';
    vec($rin,fileno(LOCALTCP),1) = 1;
    vec($rin,fileno(Server),1) = 1;
    vec($rin,fileno(Client),1) = 1;
    $ein = $rin;
#print STDERR "About to select.\n" if $debugging;
    select($rout=$rin, $wout=$win, $eout=$ein, undef);
#print STDERR "Finished selecting $rout $eout.\n" if $debugging;


    ############## Error conditions first.... ###########

    if (vec($eout,fileno(Server),1)) {
      print STDERR "Problem on the server handle.\n";
      unlink($rendezvous);
      exit 1;
    }
    if (vec($eout,fileno(LOCALTCP),1)) {
      # party's over folks....
print STDERR "Party's over\n" if $debugging;
      close Client;
      close Server;
      unlink($rendezvous);
      exit;
    }
    if (vec($eout,fileno(Client),1)) {
      # client gave up... hmm???
      close Client;
      accept(Client,Server);
      $fh=select(Client); $|=1; select ($fh);
    }


    ########## Data conditions ###################
    if (vec($rout,fileno(Server),1)) {
      close Client;
      accept(Client,Server);
      $fh=select(Client); $|=1; select ($fh);
    }
    if (vec($rout,fileno(LOCALTCP),1)) {
      sysread(LOCALTCP,$buffer,1024);
#print STDERR "Reader to Client -> $buffer\n";
      $translated_buffer = join(' ',map(ord,split(//,$buffer)));
      print Client "$translated_buffer\n";
#print STDERR "   [-> $translated_buffer]\n";
    }
    if (vec($rout,fileno(Client),1)) {
      sysread(Client,$buffer,1024);
      $fh=select(LOCALTCP); $|=1; select ($fh);
#print STDERR "Client to Writer -> $buffer\n";
      print LOCALTCP $buffer;
    }

  }
}


END { unlink ($rendezvous); }
