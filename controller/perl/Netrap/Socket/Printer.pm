package Netrap::Socket::Printer;

use strict;
use vars qw(@ISA);

use Netrap::Socket;
use Netrap::PrinterManager;

use Data::Dumper;

our %PrinterSockets;

@ISA = qw(Netrap::Socket);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $sock = shift;

    my $self = $class->SUPER::new($sock);

    bless $self, $class;

    return undef if $PrinterSockets{$self->{sock}};

    $self->{tokens} = 1;
    $self->{maxtoken} = 1;
    $self->{pos} = {};
    $self->{temps} = {
        current => {},
        target => {},
    };
    $self->addEvent('PrinterResponse');
    $self->addEvent('Token');

    $self->{FlowManager} = new Netrap::PrinterManager();
    $self->{FlowManager}->addSink($self);

    $PrinterSockets{$self->{sock}} = $self;

    return $self;
}

sub describe {
    my $self = shift;
    return sprintf "[Socket Printer %s]", $self->{name} if $self->{name};
    return sprintf "[Socket Printer FD:%d]", $self->{sock}->fileno;
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
        elsif ($w{"M"} == 140 || $w{"M"} == 190) {
            $self->{temps}->{target}->{bed} = $w{"S"};
        }
    }

    $self->SUPER::write($line);
}

sub parseResponse {
    my $self = shift;
    my $line = shift;
    for ($line) {
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
    $self->fireEvent('PrinterResponse', $line);
    for ($line) {
        if (m#\bok\b#i) {
            $self->{tokens}++ if $self->{tokens} < $self->{maxtoken};
            $self->fireEvent('Token');
            $self->fireEvent('CanWrite');
            if ($self->canwrite() == 0) {
                $self->{WriteSelector}->add($self->{sock});
            }
        }
    }
}

sub WriteSelectorCallback {
    my $self = shift;
    my $wrote;
    if ($self->{tokens} > 0) {
        $wrote = $self->SUPER::WriteSelectorCallback(1);
        printf "%s: >\t%s", $self->describe(), $wrote;
        $wrote =~ s/;.*//;
        $wrote =~ s/\(.*?\)//;
        if ($wrote =~ /[a-z]/i) {
            $self->{tokens}--;
#             printf "%s: >\t'%s'", $self->describe(), $wrote;
        }
        $self->fireEvent('Write', length($wrote), $wrote);
        if ($self->{tokens} > 0) {
            $self->fireEvent('CanWrite');
        }
    }
    if ($self->{tokens} == 0 || $self->canwrite()) {
        $self->{WriteSelector}->remove($self->{sock});
    }
}

sub ReadSelectorCallback {
    my $self = shift;

    $self->SUPER::ReadSelectorCallback(@_);

    while ($self->canread()) {
        my $line = $self->readline();
        if ($line) {
#             if ($self->{FlowManager}->nFeeders() == 0) {
                printf "%s: <\t%s\n", $self->describe(), $line;
#             }
            $self->parseResponse($line);
        }
    }
}

sub canwrite {
    my $self = shift;
    return 0 if $self->{tokens} == 0;
    return $self->SUPER::canwrite();
}

sub checkclose {
    my $self = shift;

    my $r = $self->SUPER::checkclose(@_);

    if ($r == 1) {
        delete $PrinterSockets{$self};
    }

    return $r;
}

1;
