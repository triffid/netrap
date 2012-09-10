package Netrap::FlowManager;

use Data::Dumper;
use IO::Select;
use Netrap::Socket;
use List::Util qw(first);

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
            $self->{feeders}->{$_} = $_;
            push @{$self->{feederOrder}}, "$_";
            $_->addReadNotify($self, \&Netrap::FlowManager::feederProvideData);
            $_->addCloseNotify($self, \&Netrap::FlowManager::removeFeeder);
        }
    }
    if ($sinks && ref($sinks) eq 'ARRAY') {
        for (@{$sinks}) {
            $self->{sinks}->{$_} = $_;
            push @{$self->{sinkOrder}}, "$_";
            $_->addWriteNotify($self, \&Netrap::FlowManager::sinkRequestData);
            $_->addCloseNotify($self, \&Netrap::FlowManager::removeSink);
        }
    }

    bless $self, $class;
    return $self;
}

sub addFeeder {
    my $self = shift;
    while (@_) {
        my $feeder = shift;
        $self->{feeders}->{$feeder} = $feeder;
        push @{$self->{feederOrder}}, "$feeder";
        $feeder->addReadNotify($self, \&Netrap::FlowManager::feederProvideData);
        $feeder->addCloseNotify($self, \&Netrap::FlowManager::removeFeeder);
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
        $self->{sinks}->{$sink} = $sink;
        push @{$self->{sinkOrder}}, "$sink";
        $sink->addWriteNotify($self, \&Netrap::FlowManager::sinkRequestData);
        $sink->addCloseNotify($self, \&Netrap::FlowManager::removeSink);
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
            $sink->write($feeder->readline());
            shift @{$self->{feederOrder}};
            push @{$self->{feederOrder}}, $_;
            return;
        }
    }
}

sub feederProvideData {
    my $self = shift;
#     print "feederProvideData\n";
    my $feeder = shift;
    my $line = undef;
    my @l = @{$self->{sinkOrder}};
    for (@l) {
        my $sink = $self->{sinks}->{$_};
        if ($sink->canwrite()) {
            if (!defined $line) {
                $line = $feeder->readline();
            }
            $sink->write($line);
            shift @{$self->{sinkOrder}};
            push @{$self->{sinkOrder}}, $_;
        }
    }
}

sub broadcast {
    my $self = shift;
}

1;
