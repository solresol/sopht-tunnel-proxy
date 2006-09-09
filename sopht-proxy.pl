#!/usr/bin/perl -w

use strict;
use LWP::UserAgent;
use HTML::Entities;


# Should do something smarter later.
# For now...
my $url = "http://sopht-tunnel.ifost.org.au/cgi-bin/sopht-cgi.pl";
my $target_unix_port = int (rand (34767));

# Create a user agent object
my $ua = new LWP::UserAgent;
$ua->agent("Sopht/0.1 " . $ua->agent);
$ua->env_proxy();

my $keystrokes;
my $req;
my $res;
my $this_url;

print $url."?unixport=".$target_unix_port."\n";

while (1) {
  sysread(STDIN,$keystrokes,1024);
  $keystrokes = HTML::Entities::encode_entities($keystrokes);
  $this_url = $url . "?unixport=" . $target_unix_port .
    "&keystrokes=". $keystrokes;

  # Create a request
  $req = HTTP::Request->new  ( "GET" => $this_url );
  $req->content_type('application/x-www-form-urlencoded');
  $req->content('match=www&errors=0');

  # Pass request to the user agent and get a response back
  $res = $ua->request($req,\&handle_content,1024);

  # Check the outcome of the response
  #if ($res->is_success) {
  #  print $res->content;
  #} else {
  #  print "Bad luck this time\n";
  #}
}

sub handle_content {
  my $data = shift;
  print "###]: $data\n";
}
