#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use HTTP::Daemon;
use HTTP::Response;
use HTTP::Status qw(:constants :is status_message);
use Socket qw/unpack_sockaddr_in/;

my $port = 3333;

GetOptions("port=i" => \$port);

my $d = HTTP::Daemon->new(LocalPort => $port) || die;
print "Please contact me at: <URL:", $d->url, ">\n";

while (my ($c, $peeraddr) = $d->accept) {
    next if fork();

    my $client = parse_sockaddr($c->peername);
    my $server = parse_sockaddr($c->sockname);
    my $msg = "[" . scalar(localtime) . "] > client=$client server=$server\n";
    print $msg;

    while (my $r = $c->get_request) {
        print STDERR Dumper($r), "\n";

        my $resp = HTTP::Response->new(HTTP_OK);
        $resp->content($msg);
        $c->send_response($resp);
    }

    $c->close;
    undef($c);

    $msg = "[" . scalar(localtime) . "] < client=$client server=$server\n";
    print $msg;
}

sub parse_sockaddr {
    my ($port, $ip) = unpack_sockaddr_in($_[0]);
    return inet_ntoa($ip) . ":" . $port;
}

