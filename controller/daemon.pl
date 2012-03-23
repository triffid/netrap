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

use Data::Dumper;

use SerialDevice;

my $readselect = new IO::Select(\*STDIN);
my $writeselect = new IO::Select();
my $errorselect = new IO::Select(\*STDIN, \*STDOUT);

my $printer = new SerialDevice("/dev/arduino", 115200);

$printer->select($readselect, $writeselect, $errorselect);

my $status = 0;
my $loaded = undef;
my $printing = 0;

do {
	my ($canread, $canwrite, $error) = IO::Select::select($readselect, $writeselect, $errorselect, 10);
	if (ref $error eq 'ARRAY') {
		for (@{$error}) {
			if ($_ eq \*STDIN) {
				printf("stdin closed\n");
				exit(0);
			}
			elsif ($_ eq \*STDOUT) {
				exit(1);
			}
			elsif ($printer->select_ishandle($_)) {
				$printer = undef;
				$printer = new SerialDevice("/dev/arduino", 115200);
			}
			elsif ($_ eq $loaded) {
				printf "Error reading file, finishing\n";
				$canread->remove($loaded);
				close $loaded;
				undef $loaded;
			}
			else {
				printf "error: unknown filehandle! this should never happen\n";
			}
		}
	}
	if (ref $canread eq 'ARRAY') {
		for (@{$canread}) {
			if ($printer->select_ishandle($_)) {
				$printer->select_canread();
				if ($printer->canenqueue()) {
					if ($loaded && $printing) {
						$readselect->add($loaded);
						#printf "QUEUE resume: %d\n", scalar @{$printer->{queue}};
					}
				}
			}
			elsif ($_ eq \*STDIN) {
				my $inline = <>;
				if (!defined $inline) {
					printf("stdin closed\n");
					exit(0);
				}
				chomp $inline;
				switch ($inline) {
					case /^load\s+\S.*$/ {
						$inline =~ /load\s+(\S.*)$/;
						my $f = $1;
						if (-e $f) {
							$loaded = new IO::File($f, "r");
							if ($loaded) {
								printf "%s loaded. 'print' to start printing.\n", $f;
								$printing = 0;
							}
							else {
								printf "error: open $f failed: $!\n";
							}
						}
						else {
							printf "error: %s not found\n", $1;
						}
					}
					case /^(print|resume)$/ {
						if ($loaded) {
							$readselect->add($loaded);
							printf "Starting print\n";
							$printing = 1;
						}
						else {
							printf "no file loaded! use load <filename> first\n";
						}
					}
					case /^pause$/ {
						if ($loaded) {
							$readselect->remove($loaded);
							$printing = 0;
							printf "Paused, 'resume' to resume, load <filename> to load another\n";
						}
					}
					case /^close$/ {
						if ($loaded) {
							$readselect->remove($loaded);
							close $loaded;
							undef $loaded;
							printf "Closed.\n";
							$printing = 0;
						}
						else {
							printf "Nothing to close\n";
						}
					}
					else {
						$printer->enqueue($inline);
					}
				}
			}
			elsif ($_ eq $loaded) {
				my $inline = <$_>;
				if (defined $inline) {
					chomp $inline;
					$inline =~ s/;.*//;
					$inline =~ s/\(.*?\)//;
					if ($inline =~ /[A-Z]\d/) {
						$printer->enqueue($inline);
						if (! $printer->canenqueue()) {
							$readselect->remove($loaded);
							#printf "QUEUE pause: %d\n", scalar @{$printer->{queue}};
						}
					}
				}
				else {
					printf "Finished, closing\n";
					$readselect->remove($_);
					$printing = 0;
					close $loaded;
					undef $loaded;
				}
			}
			else {
				printf "can read unknown filehandle! this should never happen.\n";
			}
		}
	}
	if (ref $canwrite eq 'ARRAY') {
		for (@{$canwrite}) {
			if ($printer->select_ishandle($_)) {
				$printer->select_canwrite();
			}
		}
	}
	while ($printer->canread()) {
		printf "< %s\n", $printer->readline();
	}
	if ($printer->canread() == 0 && $printer->canwrite() && $status == 0) {
		$printer->enqueue(
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
