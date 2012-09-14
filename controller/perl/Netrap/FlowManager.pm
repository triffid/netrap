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
    $feeder->addReceiver('Read',  $self, \&Netrap::FlowManager::feederProvideData);
    $feeder->addReceiver('Close', $self, \&Netrap::FlowManager::removeFeeder);
}

sub _addSink {
    my $self = shift;
    my $sink = shift;
    $self->{sinks}->{$sink} = $sink;
    push @{$self->{sinkOrder}}, "$sink";
    $sink->addReceiver('Write', $self, \&Netrap::FlowManager::sinkRequestData);
    $sink->addReceiver('Close', $self, \&Netrap::FlowManager::removeSink);
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
    while (@_) {
        my $feeder = shift;
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
        my $index = first { $self->{sinkOrder}->[$_] eq "$sink" } 0..$#{$self->{sinkOrder}};
        splice @{$self->{sinkOrder}}, $index, 1
            if defined $index;
        delete $self->{sinks}->{$sink};
    }
}

sub sinkRequestData {
    my $self = shift;
    my $sink = shift;
#     print "sinkRequestData\n";
    my @l = @{$self->{feederOrder}};
    for (@l) {
        my $feeder = $self->{feeders}->{$_} or die Dumper \$self;
        if ($feeder->canread()) {
            my $data;
            if ($feeder->raw()) {
                $data = $feeder->read();
            }
            else {
                $data = $feeder->readline();
            }
            $sink->write($data);
            shift @{$self->{feederOrder}};
            push @{$self->{feederOrder}}, $_;
            return $feeder;
        }
    }
}

sub feederProvideData {
    my $self = shift;
#     print "feederProvideData\n";
    my $feeder = shift;
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
            $sink->write($line);
            shift @{$self->{sinkOrder}};
            push @{$self->{sinkOrder}}, $_;
        }
    }
    return $sink;
}

sub broadcast {
    my $self = shift;
}

1;
