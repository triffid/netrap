#!/usr/bin/perl

BEGIN {
    unshift @INC, ".";
};

use strict;

use Data::Dumper;

use EventDispatch;

use IO::File;
use Netrap::Socket::File;
use Netrap::FlowManager;
use Netrap::Socket::HTTPListen;
use Netrap::Socket::NetrapListen;

# # my $f = new IO::File("< x.txt");
# my $fs = new Netrap::Socket::File("x.txt");
#
# # my $y = new IO::File("< y.txt");
# my $ys = new Netrap::Socket::File('y.txt');
#
# # my $o = new IO::File("> -") or die $!;
# my $os = new Netrap::Socket::File("-");
#
# my $fm = new Netrap::FlowManager([$fs, $ys], [$os]);


my $hl = new Netrap::Socket::HTTPListen(2560);
my $nl = new Netrap::Socket::NetrapListen(2561);
# $fm->addSink($os);
# $fm->addFeeder($s);

while (Netrap::Socket::Select()) {
}
