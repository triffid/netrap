package Netrap::Socket;

use IO::Select;
use Data::Dumper;

our %sockets;

our $ReadSelector = new IO::Select();
our $WriteSelector = new IO::Select();
our $ErrorSelector = new IO::Select();

our $lastPeriodicTime = time;

# static class method
sub Select {
    my @SelectSockets = IO::Select::select($ReadSelector, $WriteSelector, $ErrorSelector, 15);
    if (@SelectSockets) {
        my @readsockets  = @{$SelectSockets[0]};
        my @writesockets = @{$SelectSockets[1]};
        my @errorsockets = @{$SelectSockets[2]};

        for my $s (@errorsockets) {
            if ($sockets{$s}) {
                $sockets{$s}->ErrorSelectorCallback();
            }
        }
        for my $s (@readsockets) {
            if ($sockets{$s}) {
                $sockets{$s}->ReadSelectorCallback();
            }
        }
        for my $s (@writesockets) {
            if ($sockets{$s}) {
                $sockets{$s}->WriteSelectorCallback();
            }
        }
    }

    if ($lastPeriodicTime < (time - 15)) {
        for (keys %sockets) {
            $sockets{$_}->PeriodicCallback();
        }
    }
}

sub new {
	my $class = shift;

	my $socket = shift or die "Must pass a socket to Netrap::Socket::new()";

	die "Not a filehandle: " . Dumper(\$socket) unless $socket->isa("IO::Handle");

	my $self = {
		sock => $socket,
		txqueue  => [],
		replies  => [],
		txbuffer => "",
		rxbuffer => "",
		sendfile => undef,
		recvfile => undef,
		close    => 0,
		raw      => 0,
		ReadSelector => $ReadSelector,
		WriteSelector => $WriteSelector,
		ErrorSelector => $ErrorSelector,
	};

	bless $self, $class;

	$sockets{$self->{sock}} = $self;

	$ReadSelector->add($socket);
	$ErrorSelector->add($socket);

	return $self;
}

sub ReadSelectorCallback {
    my $self = shift;
    my $buf;
    my $r = sysread($self->{sock}, $buf,4096);
    $rxbuffer .= $buf;

    return if $self->{raw};

    while ($rxbuffer =~ s/^(.*?)\r?\n//e) {
        push @replies, $1;
    }
    if (@replies) {
        $self->{ReadSelector}->remove($self->{sock});
    }
}

sub WriteSelectorCallback {
    my $self = shift;
    if ((length($self->{txbuffer}) == 0) && (@{$self->{txqueue}})) {
        $txbuffer .= (shift @{$self->{txqueue}})."\n";
    }
    if (length($self->{txbuffer})) {
        my $w = syswrite($self->{sock}, $self->{txbuffer});
        substr($self->{txbuffer}, 0, $w, "");
    }
    if ((length($self->{txbuffer}) == 0) && (@{$self->{txqueue}} == 0)) {
        $self->{WriteSelector}->remove($self->{sock});
    }
}

sub ErrorSelectorCallback {
    my $self = shift;
    printf stderr "Unhandled Error on socket %s\n", $self;
    delete $sockets{$self};
}

sub PeriodicCallback {
    my $self = shift;
}

sub write {
	my $self = shift;
	if ($self->{raw}) {
        $self->{txbuffer} .= join "", @_;
	}
	else {
        push @{$self->{txqueue}}, @_;
	}
	$self->{WriteSelector}->add($self->{sock});
}

sub canread {
    my $self = shift;
    return length($self->{rxbuffer}) if $self->{raw};
	return scalar @{$self->{replies}};
}

sub canwrite {
    my $self = shift;
    return length($self->{txbuffer}) == 0 if $self->{raw};
    return @txqueue < 1;
}

sub read {
    my $self = shift;
    if ($self->{raw}) {
        my $r = $self->{rxbuffer};
        $self->{rxbuffer} = "";
        return $r;
    }
    return $self->readline();
}

sub readline {
    my $self = shift;
    $self->{ReadSelector}->add($self->{sock});
    if ($self->{raw}) {
        $self->{rxbuffer} =~ s/^(.*?\r?\n)//s;
        return $1;
    }
    else {
        return shift @{$self->{replies}} or undef;
    }
}

sub raw {
    my $self = shift;
    if (@_) {
        $self->{raw} = (shift)?1:0;
    }
    return $self->{raw};
}

1;
