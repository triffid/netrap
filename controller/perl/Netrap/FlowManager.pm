package Netrap::FlowManager;

use strict;

use Data::Dumper;
use IO::Select;
use Netrap::Socket;
use List::Util qw(first);

sub _addFeeder {
    my $self = shift;
    my $feeder = shift or die;
    $self->{feeders}->{$feeder} = $feeder;
    push @{$self->{feederOrder}}, "$feeder";
    $feeder->addReceiver('Read',  $self, $self->can('feederProvideData')) unless $self->{frozen};
    $feeder->addReceiver('Close', $self, $self->can('removeFeeder'));
}

sub _addSink {
    my $self = shift;
    my $sink = shift;
    $self->{sinks}->{$sink} = $sink;
    push @{$self->{sinkOrder}}, "$sink";
    $sink->addReceiver('CanWrite', $self, $self->can('sinkRequestData')) unless $self->{frozen};
    $sink->addReceiver('Close', $self, $self->can('removeSink'));
}

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self = {};

    $self->{ReadSelector} = $Netrap::Socket::ReadSelector;
    $self->{WriteSelector} = $Netrap::Socket::WriteSelector;
    $self->{ErrorSelector} = $Netrap::Socket::ErrorSelector;

    $self->{broadcast} = 0;

    $self->{feeders} = {};
    $self->{feederOrder} = [];
    $self->{feederLast} = undef;

    $self->{sinks} = {};
    $self->{sinkOrder} = [];
    $self->{sinkLast};

    $self->{frozen} = 0;

    my ($feeders, $sinks) = @_;

    if ($feeders && ref($feeders) eq 'ARRAY') {
        for (@{$feeders}) {
            _addFeeder($self, $_);
        }
    }
    if ($sinks && ref($sinks) eq 'ARRAY') {
        for (@{$sinks}) {
            _addSink($self, $_);
        }
    }

    bless $self, $class;
    return $self;
}

sub describe {
    my $self = shift;
    return sprintf "[FlowManager: %d feeders, %d sinks]", scalar(@{$self->{feederOrder}}), scalar(@{$self->{sinkOrder}});
}

sub addFeeder {
    my $self = shift;
    while (@_) {
        my $feeder = shift;
        _addFeeder($self, $feeder);
        if ($feeder->canread()) {
            $self->feederProvideData($feeder);
        }
    }
}

sub removeFeeder {
    my $self = shift;
    while (my $feeder = shift) {
#         printf "removing feeder %s\n", $feeder;
        $feeder->removeReceiver('Read', $self, $self->can('feederProvideData')) unless $self->{frozen};
        $feeder->removeReceiver('Close', $self, $self->can('removeFeeder'));
#         printf "Feeder receivers: %s\n", Dumper $feeder->{Events};
        my $index = first { $self->{feederOrder}->[$_] eq "$feeder" } 0..$#{$self->{feederOrder}};
        splice @{$self->{feederOrder}}, $index, 1
            if defined $index;
        delete $self->{feeders}->{$feeder};
    }
}

sub addSink {
    my $self = shift;
    while (@_) {
        my $sink = shift;
        _addSink($self, $sink);
        if ($sink->canwrite()) {
            $self->sinkRequestData($sink);
        }
    }
}

sub removeSink {
    my $self = shift;
    while (@_) {
        my $sink = shift;
        $sink->removeReceiver('CanWrite', $self, $self->can('sinkRequestData')) unless $self->{frozen};
        $sink->removeReceiver('Close', $self, $self->can('removeSink'));
        my $index = first { $self->{sinkOrder}->[$_] eq "$sink" } 0..$#{$self->{sinkOrder}};
        splice @{$self->{sinkOrder}}, $index, 1
            if defined $index;
        delete $self->{sinks}->{$sink};
    }
}

sub sinkRequestData {
    my $self = shift;
    my $sink = shift;

#     printf "sinkRequestData\n";

    return undef if $self->{frozen};

    my @l = @{$self->{feederOrder}};
    for (@l) {
        my $feeder = $self->{feeders}->{$_} or die Dumper \$self;
        if ($feeder->canread()) {
            my $data;
#             printf "%s can read; ", $feeder->describe();
            if ($feeder->raw()) {
                $data = $feeder->read();
            }
            else {
                $data = $feeder->readline();
            }
            my $displaydata = $data;
            $displaydata =~ s/([\x0-\x1A\x7E-\xFF])/sprintf "\\x%02X", ord $1/ge;
            printf "%s provides '%s'\n", $feeder->describe(), $displaydata;
            if (defined $data) {
                $sink->write($data);
                push @{$self->{feederOrder}}, shift @{$self->{feederOrder}};
#                 printf "sinkRequestData: got data from feeder %s\n", $feeder;
                return $feeder;
            }
        }
        else {
#             printf "%s can't read\n", $feeder->describe();
        }
    }
}

sub feederProvideData {
    my $self = shift;
    my $feeder = shift;

    return undef if $self->{frozen};

    my $line = undef;
    my @l = @{$self->{sinkOrder}};
    my $sink;

    for (@l) {
        $sink = $self->{sinks}->{$_};
        if ($sink->canwrite()) {
            if (!defined $line) {
                if ($feeder->raw()) {
                    $line = $feeder->read();
                }
                else {
                    $line = $feeder->readline();
                }
            }
            my $displaydata = $line;
            $displaydata =~ s/([\x0-\x1A\x80-\xFF])/sprintf "\\x%02X", ord $1/ge;
            printf "%s provides '%s'\n", $feeder->describe(), $displaydata;
            $sink->write($line);
#             printf "Wrote \"%s\" to %s\n", $line, $sink->describe();
            shift @{$self->{sinkOrder}};
            push @{$self->{sinkOrder}}, $_;
            return $sink;
        }
    }
    return undef
}

sub broadcast {
    my $self = shift;
}

sub nSinks {
    my $self = shift;
    return scalar @{$self->{sinkOrder}};
}

sub nFeeders {
    my $self = shift;
    return scalar @{$self->{feederOrder}};
}

sub freeze {
    my $self = shift;
    my $frozen = shift;

    return if (($frozen?1:0) == $self->{frozen});
    if ($frozen) {
        for (values %{$self->{feeders}}) {
            $_->removeReceiver('Read',  $self, $self->can('feederProvideData'));
        }
        for (values %{$self->{sinks}}) {
            $_->removeReceiver('CanWrite', $self, $self->can('sinkRequestData'));
        }
        $self->{frozen} = 1;
    }
    else {
        $self->{frozen} = 0;
        for (values %{$self->{feeders}}) {
            $_->addReceiver('Read',  $self, $self->can('feederProvideData'));
            if ($_->canread()) {
                $self->feederProvideData($_);
            }
        }
        for (values %{$self->{sinks}}) {
            $_->addReceiver('CanWrite', $self, $self->can('sinkRequestData'));
            if ($_->canwrite()) {
                $self->sinkRequestData($_);
            }
        }
    }
}

1;
