package Netrap::Socket;

use strict;

use IO::Select;
use Data::Dumper;

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

    if ($lastPeriodicTime < (time - 15)) {
        for (keys %sockets) {
            $sockets{$_}->PeriodicCallback();
        }
    }

    return 1;
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
        ReadNotify  => [],
        WriteNotify => [],
        ErrorNotify => [],
        CloseNotify => [],
    };

    bless $self, $class;

    $sockets{$self->{sock}} = $self;

    $ReadSelector->add($socket);
    $ErrorSelector->add($socket);

    return $self;
}

sub ReadSelectorCallback {
    my $self = shift;

    if ($self->{close} && !$self->canread()) {
        for (@{$self->{CloseNotify}}) {
            my ($instance, $function) = @{$_};
            $function->($instance, $self);
        }

        $ReadSelector->remove($self->{sock});
        $WriteSelector->remove($self->{sock});
        $ErrorSelector->remove($self->{sock});
        delete $sockets{$self};
        close($self->{sock});
#         print "Closed\n";
#         print Dumper \$self;
    }

    my $buf;
    my $r = sysread($self->{sock}, $buf,4096);
#     printf "Read %d bytes from %s\n", $r, $self->{sock}; #, $buf;
    $self->{rxbuffer} .= $buf;

    if (!$self->{raw}) {
        while ($self->{rxbuffer} =~ s/^(.*?)\r?\n//e) {
            push @{$self->{replies}}, $1;
        }
        if (@{$self->{replies}} > 0) {
            $ReadSelector->remove($self->{sock});
        }
    }
    else {
        if (length($self->{rxbuffer})) {
            $ReadSelector->remove($self->{sock});
        }
    }

    if ($r > 0) {
        for (@{$self->{ReadNotify}}) {
            my ($instance, $function) = @{$_};
            $function->($instance, $self);
        }
    }

    return $r;
}

sub WriteSelectorCallback {
    my $self = shift;
#     printf "CanWrite: %s\n", $self;

    if ((length($self->{txbuffer}) == 0) && (@{$self->{txqueue}})) {
#         printf "Filling txbuffer from txqueue\n";
        $self->{txbuffer} .= (shift @{$self->{txqueue}})."\n";
    }
    if (length($self->{txbuffer})) {
        my $w = syswrite($self->{sock}, $self->{txbuffer});
#         printf "Wrote %d bytes: %s\n", $w,
            substr($self->{txbuffer}, 0, $w, "");
        if ($w > 0) {
            for (@{$self->{WriteNotify}}) {
                my ($instance, $function) = @{$_};
                $function->($instance, $self);
            }
        }
    }
    if ((length($self->{txbuffer}) == 0) && (@{$self->{txqueue}} == 0)) {
        $WriteSelector->remove($self->{sock});
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
    return 1 if @{$self->{replies}};
    return 1 if length($self->{rxbuffer});
    return 0;
}

sub canwrite {
    my $self = shift;

#     printf "CanWrite: %s", Dumper \$self;

    return 0 if length($self->{txbuffer});
    return 0 if @{$self->{txqueue}};
    return 1;
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
        $self->{raw} = (shift)?1:0;
    }
    return $self->{raw};
}

sub addReadNotify {
    my $self = shift;
    my ($instance, $function) = @_;
    push @{$self->{ReadNotify}}, [$instance, $function];
}

sub addWriteNotify {
    my $self = shift;
    my ($instance, $function) = @_;
    push @{$self->{WriteNotify}}, [$instance, $function];
}

sub addErrorNotify {
    my $self = shift;
    my ($instance, $function) = @_;
    push @{$self->{ErrorNotify}}, [$instance, $function];
}

sub addCloseNotify {
    my $self = shift;
    my ($instance, $function) = @_;
    push @{$self->{CloseNotify}}, [$instance, $function];
}

1;
