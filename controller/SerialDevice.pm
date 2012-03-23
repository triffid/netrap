package SerialDevice;

use strict;
use warnings;

use SerialPort;

use POSIX;
use IO::Handle;
use IO::Select;

use Data::Dumper;

my $debug = 0;

my $max_queue = 1;

sub new {
	my $class = shift;
	my $port  = shift;
	my $baud  = shift;
	
	my $self = {
		device => $port,
		baud => $baud,
		queue => [],
		rxbuffer => "",
		buffer_size => 256,
		token => 0,
		readselect => undef,
		writeselect => undef,
		errorselect => undef,
	};
	
	print STDERR "Open $port @ $baud\n" if $debug;
	
	$self->{port} = new Device::SerialPort($port) or die "cannot open port $port: $!";
	$self->{port}->databits(8);
	$self->{port}->baudrate(115200);
	$self->{port}->parity("none");
	$self->{port}->stopbits(1);
	$self->{port}->handshake("xoff"); # some firmwares support XON/XOFF, the gcode send/receive protocol does not allow for XON/XOFF characters in standard messages.
	$self->{port}->write_settings() or die "could not set $port options: $!";
	$self->{port}->read_const_time(0);
	$self->{port}->read_char_time(0);

	bless $self, $class;
	return $self;
}

sub canread {
	my $self = shift;
	if (length $self->{rxbuffer}) {
		if ($self->{rxbuffer} =~ /\n/) {
			return 1;
		}
	}
	return 0;
}

sub canwrite {
	my $self = shift;
	return $self->{token};
}

sub readline {
	my $self = shift;
	if (length $self->{rxbuffer}) {
		if ($self->{rxbuffer} =~ s/^(.*?)\r?\n//s) {
			my $line = $1;
			if ($line =~ /\b(ok|start)\b/i) {
				$self->{token}++;
				printf STDERR "TOKEN: %d, QUEUE: %d\n", $self->{token}, scalar @{$self->{queue}} if $debug;
				if (@{$self->{queue}}) {
					$self->{writeselect}->add($self->{port}->{HANDLE});
				}
			}
			return $line;
		}
	}
}

sub canenqueue {
	my $self = shift;
	my $num = shift || 1;
	return scalar @{$self->{queue}} + $num <= $max_queue;
}

sub enqueue {
	my $self = shift;
	printf STDERR "Enqueue: @_\n" if $debug;
	my $items = push @{$self->{queue}}, @_;
	printf STDERR "Enqueued $items lines\n" if $debug;
	if ($self->{token}) {
		$self->{writeselect}->add($self->{port}->{HANDLE});
		if (IO::Select::select(undef, $self->{writeselect}, undef, 0)) {
			select_canwrite();
		}
	}
}

sub select {
	my ($self, $readselect, $writeselect, $errorselect) = @_;
	$readselect->add($self->{port}->{HANDLE});
	$self->{readselect} = $readselect;
	$self->{writeselect} = $writeselect;
	$self->{errorselect} = $errorselect;
}

sub select_ishandle {
	my ($self, $handle) = @_;
	return $self->{port}->{HANDLE} == $handle;
}

sub select_canread {
	my $self = shift;
	my ($count, $data) = $self->{port}->read(256);
	printf STDERR "read %d: %s\n", $count, $data if $debug && $count;
	$self->{rxbuffer} .= $data;
}

sub select_canwrite {
	my $self = shift;
	if ($self->{token}) {
		if (@{$self->{queue}}) {
			my $line = shift @{$self->{queue}};
			printf STDERR "> %s\n", $line;
			$self->{port}->write($line."\n") or die "write failed: $!";
			$self->{token}--;
			printf STDERR "WROTE \"%s\", TOKEN %d, QUEUE %d\n", $line, $self->{token}, scalar @{$self->{queue}} if $debug;
			if ($self->{token} == 0) {
				$self->{writeselect}->remove($self->{port}->{HANDLE});
			}
		}
		else {
			$self->{writeselect}->remove($self->{port}->{HANDLE});
		}
	}
}

sub select_error {
	my $self = shift;
}

1;
