#!/usr/bin/perl

BEGIN {
	use FindBin;
	use lib "$FindBin::Bin/";
}

use strict;
use warnings;

use POSIX;
use Switch;

use IO::Handle;
use IO::File;
use IO::Select;
use IO::Socket::INET;

use Socket qw(SOL_SOCKET SO_KEEPALIVE);

use Data::Dumper;

use SerialDevice;

my $printer_port = "/dev/arduino";
my $printer_baud = 115200;

my $listen_port = 2560;

#***************************************************************************#

my $netsocket = new IO::Socket::INET(LocalPort => $listen_port,
                                     Listen   => SOMAXCONN,
                                     Blocking => 0,
                                     Type     => SOCK_STREAM,
                                     Reuse    => 1) or die "listen failed: $!";

my %sockets;

my %receivers = ( \*STDIN => {} );

my $readselect = new IO::Select(\*STDIN, $netsocket);
my $writeselect = new IO::Select();
my $errorselect = new IO::Select(\*STDIN, \*STDOUT);

my $printer = new SerialDevice($printer_port, $printer_baud);
$printer->select($readselect, $writeselect, $errorselect);

my $status = 0;
my $loaded = undef;
my $loadedfn = undef;
my $printing = 0;

sub close_loaded {
	if ($loaded) {
		$printer->closequeue($loaded);
		$readselect->remove($loaded);
		$printing = 0;
		close $loaded;
		undef $loaded;
	}
}

my $outputrunner = sub {
	my ($sender, $line) = @_;
	printf STDERR "< %s\n", $line;
};

$printer->add_listener($outputrunner);

sub parseInputLine {
	my ($source, $replydest, $inline) = @_;
	chomp $inline;
	switch ($inline) {
		case /^poke$/ {
			$printer->{token}++;
			$writeselect->add($printer->{port}->{HANDLE});
		}
		case /^load\s+\S.*$/ {
			$inline =~ /load\s+(\S.*)$/;
			my $f = $1;
			if (-e $f) {
				$loaded = new IO::File($f, "r");
				if ($loaded) {
					$loadedfn = $f;
					printf $replydest "%s loaded. 'print' to start printing.\n", $f;
					$printing = 0;
				}
				else {
					printf $replydest "error: open $f failed: $!\n";
				}
			}
			else {
				printf $replydest "error: %s not found\n", $1;
			}
		}
		case /^(print|resume)$/ {
			if ($loaded) {
				$readselect->add($loaded);
				printf $replydest "Starting print\n";
				$printing = 1;
			}
			else {
				printf $replydest "no file loaded! use load <filename> first\n";
			}
		}
		case /^restart$/ {
			if ($loaded) {
				seek($loaded, 0, 0);
				$printing = 0;
				printf $replydest "Position reset to 0. use print to start\n"
			}
		}
		case /^pause$/ {
			if ($loaded) {
				$readselect->remove($loaded);
				$printing = 0;
				printf $replydest "Paused, 'resume' to resume, load <filename> to load another\n";
			}
		}
		case /^status$/ {
			printf $replydest "Status:\n";
			if ($loaded) {
				printf $replydest "\tLoaded: %s\n", $loadedfn;
				if ($printing) {
					printf $replydest "\t\tPrinting\n";
				}
				else {
					printf $replydest "\t\tPaused\n";
				}
				printf $replydest "\t\tAt line: %s\n", $loaded->input_line_number;
				printf $replydest "\t\tAt byte position: %d of %d\n", tell($loaded), (-s $loaded);
			}
			else {
				printf $replydest "\tNo file loaded\n";
			}
			if (keys %sockets) {
				printf $replydest "\tConnections:\n";
				for (keys %sockets) {
					printf $replydest "\t\t%s:%d\n", $sockets{$_}->{PeerAddr}, $sockets{$_}->{PeerPort};
				}
			}
			last;
		}
		case /^close$/ {
			if ($loaded) {
				close_loaded();
				printf $replydest "Closed.\n";
			}
			else {
				printf $replydest "Nothing to close\n";
			}
		}
		case /^dump$/ {
			printf $replydest Data::Dumper->Dump([$printer], ['printer']);
			printf $replydest Data::Dumper->Dump([\%sockets], ['sockets']);
		}
		case /^exit$/ {
			if (ref($source) eq 'HASH' && exists $source->{socket}) {
				printf $replydest "Goodbye\n";
				printf STDERR "Connection from %s:%d closed\n", $source->{PeerAddr}, $source->{PeerPort};
				$printer->remove_listener($source);
				$readselect->remove($replydest);
				delete $sockets{$source->{socket}};
				$replydest->close();
			}
			elsif ($source eq \*STDIN) {
				# TODO: more elegant shutdown
				exit(0);
			}
		}
		else {
			if ($inline =~ /\S/) {
				$printer->enqueue(\*STDIN, $inline);
			}
			last;
		}
	}
}

do {
	my ($canread, $canwrite, $error) = IO::Select::select($readselect, $writeselect, $errorselect, 10);
	$printer->onselect($canread, $canwrite, $error);
	if ($printer->error) {
		$printer = undef;
		$printer = new SerialDevice("/dev/arduino", 115200) or die "Can't open /dev/arduino: $!";
		$printer->add_listener($outputrunner);
	}
	if (ref $error eq 'ARRAY') {
		for (@{$error}) {
			if ($_ eq \*STDIN) {
				printf("stdin closed\n");
				$readselect->remove(\*STDIN);
				$errorselect->remove(\*STDIN);
				exit(0) unless $loaded;
			}
			elsif ($_ eq \*STDOUT) {
				$writeselect->remove(\*STDOUT);
				$errorselect->remove(\*STDOUT);
				exit(1) unless $loaded;
			}
			elsif ($_ eq $loaded) {
				printf "Error reading file, finishing\n";
				close_loaded();
			}
			else {
				$printer->remove_listener($_);
			}
		}
	}
	if (ref $canread eq 'ARRAY') {
		for (@{$canread}) {
			if ($_ eq \*STDIN) {
				my $inline = <>;
				if (!defined $inline) {
					printf("stdin closed\n");
					exit(0);
				}
				parseInputLine(\*STDIN, \*STDOUT, $inline);
			}
			elsif ($loaded && $_ eq $loaded) {
				my $inline = <$_>;
				if (defined $inline) {
					chomp $inline;
					$inline =~ s/;.*//;
					$inline =~ s/\(.*?\)//;
					if ($inline =~ /[A-Z]\d/) {
						$printer->enqueue($loaded, $inline);
						if ($printer->canenqueue($loaded) <= 0) {
							#printf STDERR "Print Queue full\n";
							$readselect->remove($loaded);
						}
					}
				}
				else {
					printf "Finished. close to release file\n";
					$readselect->remove($loaded);
					$printing = 0;
				}
			}
			elsif ($_ eq $netsocket) {
				# new connection
				my ($newsocket, $address) = $netsocket->accept();
				$newsocket->blocking(0);
				setsockopt($newsocket, SOL_SOCKET, SO_KEEPALIVE,  1);
				$sockets{$newsocket} = { PeerAddr => join(".", (unpack('SnCCCC', $address))[2,3,4,5]),
				                         PeerPort => (unpack('SnCCCC', $address))[1],
				                         ConnectionTime => gmtime(),
				                         rxqueue => "",
				                         txqueue => [],
				                         socket => $newsocket, };
				printf STDERR "Got connection from %s:%d\n", $sockets{$newsocket}->{PeerAddr}, $sockets{$newsocket}->{PeerPort};
				$printer->add_listener($sockets{$newsocket});
				#close $newsocket[0];
				$readselect->add($newsocket);
			}
			elsif (exists $sockets{$_}) {
				my $data;
				my $count = $_->read($data, 1024);
				if (defined $count && $count > 0) {
					#printf "Read '%s' from %s:%d\n", $data, $sockets{$_}->{PeerAddr}, $sockets{$_}->{PeerPort};
					$sockets{$_}->{rxqueue} .= $data;
					while (exists $sockets{$_} && $sockets{$_}->{rxqueue} =~ s/^(.*?)\n//) {
						parseInputLine($sockets{$_}, $_, $1);
					}
				}
				else {
					printf STDERR "Connection from %s:%d closed\n", $sockets{$_}->{PeerAddr}, $sockets{$_}->{PeerPort};
					$printer->remove_listener($sockets{$_});
					$readselect->remove($_);
					delete $sockets{$_};
					$_->close();
				}
			}
		}
	}
	if (ref $canwrite eq 'ARRAY') {
		for (@{$canwrite}) {
			if (exists $sockets{$_}) {
				if ($sockets{$_}->{txqueue}) {
					$_->write(shift(@{$sockets{$_}->{txqueue}}) . "\n");
				}
				if (@{$sockets{$_}->{txqueue}} == 0) {
					$writeselect->remove($_);
				}
			}
		}
	}
	if ($printer->canenqueue($loaded) > 0 && $loaded && $printing) {
		#printf STDERR "Print Queue filling\n";
		$readselect->add($loaded);
	}
	if ($printer->canread() == 0 && $printer->canwrite() && $status == 0) {
		$printer->enqueue(\*STDIN,
			"M115",
			"M114",
			"M119",
			"M105",
			"M115",
			"M114",
			"M105"
			);
		$status = 1;
	}
} while (1);

$netsocket->close();
