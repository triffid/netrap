#!/usr/bin/perl

BEGIN {
    use FindBin;
    unshift @INC, $FindBin::Bin;
};

use strict;

use Data::Dumper;

use EventDispatch;

use IO::File;
use Netrap::Socket::File;
use Netrap::FlowManager;
use Netrap::Socket::HTTPListen;
use Netrap::Socket::NetrapListen;


my $hl = new Netrap::Socket::HTTPListen(2560);
my $nl = new Netrap::Socket::NetrapListen(2561);

while (Netrap::Socket::Select()) {
    EventDispatch::runEvents();
}
