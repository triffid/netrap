package Netrap::Socket::Printer;

use strict;

use Netrap::Socket;

our %PrinterSockets;

@ISA = qw(Netrap::Socket);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $sock = shift;

    my $self = $class->SUPER::new($sock);

    $self->{tokens} = 1;
    $self->{pos} = {};
    $self->{temps} = {
        current => {},
        target => {},
    };

    $self->addEvent('PrinterResponse');
    $self->addEvent('Token');

    bless $self, $class;

    $PrinterSockets{$self->{sock}} = $self;

    return $self;
}

sub write {
    my $self = shift;
    my $line = shift;
    $self->parseRequest($line);
}

sub parseRequest {
    my $self = shift;
    my $line = shift;

    $self->{request} = $line;

    my %w;

    while ($line =~ /([A-Z])\s*(\d+(\.\d+)?)/g) {
        $w{$1} = $2;
    }

    if (defined $w{"G"}) {
        if ($w{"G"} == 0 || $w{"G"} == 1 || $w{"G"} == 92) {
            for (split //, "ABCDEFXYZ") {
                if (defined $w{$_}) {
                    $self->{pos}->{$_} = $w{$_};
                }
            }
        }
    }
    if (defined $w{"M"}) {
        if ($w{"M"} == 104 || $w{"M"} == 109) {
            $self->{temps}->{target}->{nozzle} = $w{"S"};
        }
        elif ($w{"M"} == 140 || $w{"M"} == 190) {
            $self->{temps}->{target}->{bed} = $w{"S"};
        }
    }
}

sub parseResponse {
    my $self = shift;
    my $line = shift;
    if (m#\bok\b#) {
        $self->{tokens} += 1;
        if ($self->canwrite()) {
            $self->{WriteSelector}->add($self->{sock});
        }
        $self->fireEvent('Token', $self);
    }
    if (m#T\s*:\s*(\d+(\.\d+))(\s*/(\d+(\.\d+)?))#) {
        $self->{temps}->{current}->{nozzle} = $1;
        $self->{temps}->{target}->{nozzle} = $4 if $4;
    }
    if (m#B\s*:\s*(\d+(\.\d+))(\s*/(\d+(\.\d+)?))#) {
        $self->{temps}->{current}->{bed} = $1;
        $self->{temps}->{target}->{bed} = $4 if $4;
    }
    if ($self->{request} =~ /\bM114\b/) {
        if (m#([XYZE]):(\d(\.\d+))#) {
            $self->{pos}->{$1} = $2;
        }
    }
}

sub WriteSelectorCallback {
    my $self = shift;
    if ($self->{tokens} > 0) {
        $self->SUPER::WriteSelectorCallback(@_);
    }
    else {
        $self->{WriteSelector}->remove($self->{sock});
    }
}

sub ReadSelectorCallback {
    my $self = shift;

    $self->SUPER::ReadSelectorCallback(@_);

    while ($self->canread()) {
        my $line = $self->readline();
        $self->parseResponse($line);
        $self->fireEvent('PrinterResponse', $self, $line);
    }
}

1;
