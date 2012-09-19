package Netrap::Socket;

use strict;
use vars qw(@ISA);

use IO::Select;
use Data::Dumper;
use EventDispatch;
use Scalar::Util qw(looks_like_number);

our %sockets;

our $ReadSelector = new IO::Select();
our $WriteSelector = new IO::Select();
our $ErrorSelector = new IO::Select();

our $lastPeriodicTime = time;

# static class method
sub Select {
    return 0 if $ErrorSelector->handles() == 0;

#     print Dumper [$ReadSelector, $WriteSelector, $ErrorSelector];
    my @SelectSockets = IO::Select::select($ReadSelector, $WriteSelector, $ErrorSelector, 15);
#     print Dumper \@SelectSockets;
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
    else {
        # timeout
    }

    if ($lastPeriodicTime < (time - 15)) {
        for (keys %sockets) {
            $sockets{$_}->PeriodicCallback();
        }
    }

    return 1;
}

@ISA = qw(EventDispatch);

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
#         ReadNotify  => [],
#         WriteNotify => [],
#         ErrorNotify => [],
#         CloseNotify => [],
    };

    bless $self, $class;

    $self->EventDispatch::init();
    $self->addEvent('Read');
    $self->addEvent('Write');
    $self->addEvent('Error');
    $self->addEvent('Close');

    $sockets{$self->{sock}} = $self;

    $ReadSelector->add($socket);
    $ErrorSelector->add($socket);

    return $self;
}

sub describe {
    my $self = shift;
    return sprintf "[Socket FD:%d]", $self->{sock}->fileno;
}

sub ReadSelectorCallback {
    my $self = shift;
    my $suppressEvents = shift;

    return if $self->checkclose();

    my $buf;
    my $r = sysread($self->{sock}, $buf,4096);

    if ($r == 0) {
        $self->close();
    }
    printf "Read %d bytes from %s\n", $r, $self->{sock}; #, $buf;
    $self->{rxbuffer} .= $buf;

    if (!$self->{raw}) {
        while ($self->{rxbuffer} =~ s/^(.*?)\r?\n//e) {
            push @{$self->{replies}}, $1;
        }
        my $nreplies = scalar(@{$self->{replies}}) + 1;
        while (@{$self->{replies}} < $nreplies) {
            $nreplies = @{$self->{replies}};
#             printf "Read [%s]\n", $self->{replies}->[0];
            $self->fireEvent('Read') unless $suppressEvents;
        }
        if (@{$self->{replies}} > 0) {
            $ReadSelector->remove($self->{sock}) unless $self->{close};
        }
    }
    else {
        if (length($self->{rxbuffer})) {
            $ReadSelector->remove($self->{sock}) unless $self->{close};
            $self->fireEvent('Read');
        }
    }

    return $r;
}

sub WriteSelectorCallback {
    my $self = shift;
    my $suppressEvents = shift;
#     printf "CanWrite: %s Close: %d canread: %d canwrite %d\n", $self, $self->{close}, $self->canread(), $self->canwrite();

    return if $self->checkclose();

    my $w = 0;
    my $written = undef;

    if ((length($self->{txbuffer}) == 0) && (@{$self->{txqueue}})) {
#         printf "Filling txbuffer from txqueue\n";
        $self->{txbuffer} .= (shift @{$self->{txqueue}})."\n";
    }
    if (length($self->{txbuffer})) {
        $w = syswrite($self->{sock}, $self->{txbuffer});
#         printf "Wrote %d of %d bytes: %s\n", $w, length($self->{txbuffer}),
        $written = substr($self->{txbuffer}, 0, $w, "");
        if ($w > 0) {
            $self->fireEvent('Write', $w, $written) unless $suppressEvents;
        }
        else {
            $self->close();
        }
    }
    if (
        (length($self->{txbuffer}) == 0) &&
        (@{$self->{txqueue}} == 0) &&
        ($self->{close} == 0)
       ) {
        $WriteSelector->remove($self->{sock});
    }

    return $written if $w;
    return undef;
}

sub ErrorSelectorCallback {
    my $self = shift;
    printf stderr "Unhandled Error on socket %s\n", $self;
    $self->fireEvent('Error');
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
    return 1 if @{$self->{replies}};
    return 1 if length($self->{rxbuffer});
    return 0;
}

sub canwrite {
    my $self = shift;

#     printf "CanWrite: %s", Dumper \$self;

    return 0 if length($self->{txbuffer});
    return 0 if @{$self->{txqueue}} > 0;
    return 1;
}

sub read {
    my $self = shift;
#     die "read";
    if ($self->{raw}) {
#         die "raw read";
        my $max = shift;
        $max = 4096 unless looks_like_number($max);
        $max = length($self->{rxbuffer}) if $max > length($self->{rxbuffer});
        $max = 1 if $max == 0;
#         printf "\t[max = %d]\n", $max;
        my $r = substr($self->{rxbuffer}, 0, $max, "");
        if (length($self->{rxbuffer}) == 0) {
            $ReadSelector->add($self->{sock});
        }
        return $r;
    }
    return $self->readline();
}

sub peekline {
    my $self = shift;
    if ($self->{raw}) {
        $self->{rxbuffer} =~ /^(.*?\r?\n)/;
        return $1;
    }
    else {
        return $self->{replies}->[0] or undef;
    }
}

sub readline {
    my $self = shift;
    if ($self->{raw}) {
        $self->{rxbuffer} =~ s/^(.*?\r?\n)//s;
        $self->{ReadSelector}->add($self->{sock})
            if length($self->{rxbuffer}) == 0;
        return $1;
    }
    else {
        if (@{$self->{replies}} <= 1) {
            $self->{ReadSelector}->add($self->{sock});
#             print "Last Line read, re-listening\n";
        }
        return shift @{$self->{replies}} or undef;
    }
}

sub raw {
    my $self = shift;
    if (@_) {
        $self->{raw} = shift // $self->{raw};
        if ($self->{raw} && @{$self->{txqueue}} > 0) {
            $self->{txbuffer} .= join("\n", splice(@{$self->{txqueue}}, 0))."\n";
        }
        if ($self->{raw} && @{$self->{replies}} > 0) {
            $self->{rxbuffer} .= join("\n", splice(@{$self->{replies}}, 0))."\n";
        }
    }
    return $self->{raw};
}

sub checkclose {
    my $self = shift;

#     print "%s CheckClose: ", $self;

    if ($self->{close} && !$self->canread() && $self->canwrite()) {
        return 1 if $self->{isclosed};
#         printf "%s:fireEvent('Close')\n", $self;
        $self->fireEvent('Close');

        $ReadSelector->remove($self->{sock});
        $WriteSelector->remove($self->{sock});
        $ErrorSelector->remove($self->{sock});
        delete $sockets{$self};
        close($self->{sock});
        $self->{isclosed} = 1;
#         printf "%s Closed\n", $self->describe();
        return 1;
    }
#     printf "%d %d %d (%d %d)\n", $self->{close}, $self->canread(), $self->canwrite(), length($self->{txbuffer}), scalar(@{$self->{txqueue}});
    return 0;
}

sub close {
    my $self = shift;
    $self->{close} = 1;
    $WriteSelector->add($self->{sock});
    $ReadSelector->remove($self->{sock});
}

sub flushrx {
    my $self = shift;
    $self->{replies} = [];
    $self->{rxbuffer} = '';
}

1;
