#!/usr/bin/perl

BEGIN {
    unshift @INC, ".";
};

use strict;

use Data::Dumper;

use IO::File;
use Netrap::Socket::File;
use Netrap::FlowManager;

my $f = new IO::File("< x.txt");
my $fs = new Netrap::Socket::File($f);

my $y = new IO::File("< y.txt");
my $ys = new Netrap::Socket::File($y);

my $o = new IO::File("> -") or die $!;
my $os = new Netrap::Socket::File($o);

my $fm = new Netrap::FlowManager([$fs, $ys], [$os]);

# $fm->addSink($os);
# $fm->addFeeder($s);

while (Netrap::Socket::Select()) {
    exit 0 if (keys %{$fm->{feeders}}) == 0 && $os->canwrite();
}
