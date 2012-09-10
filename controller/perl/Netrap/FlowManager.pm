package Netrap::FlowManager;

use IO::Select;
use Netrap::Socket;

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

    $self->{sinks} = {};
    $self->{sinkOrder} = [];

    my ($feeders, $sinks) = @_;

    if ($feeders && ref($feeders) eq 'ARRAY') {
        for (@{$feeders}) {
            $self->{feeders}->{$_} = $_;
            $_->addReadNotify($self, \&Netrap::FlowManager::feederProvideData);
            $_->addCloseNotify($self, \&Netrap::FlowManager::removeFeeder);
        }
    }
    if ($sinks && ref($sinks) eq 'ARRAY') {
        for (@{$sinks}) {
            $self->{sinks}->{$_} = $_;
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
        $feeder->addReadNotify($self, \&Netrap::FlowManager::feederProvideData);
        if ($feeder->canread()) {
            $self->feederProvideData($feeder);
        }
    }
}

sub removeFeeder {
    my $self = shift;
    while (@_) {
        my $feeder = shift;
        delete $self->{feeders}->{$feeder};
    }
}

sub addSink {
    my $self = shift;
    while (@_) {
        my $sink = shift;
        $self->{sinks}->{$sink} = $sink;
        $sink->addWriteNotify($self, \&Netrap::FlowManager::sinkRequestData);
        if ($sink->canwrite()) {
            $self->sinkRequestData($sink);
        }
    }
}

sub removeSink {
    my $self = shift;
    while (@_) {
        my $sink = shift;
        delete $self->{sinks}->{$sink};
    }
}

sub sinkRequestData {
    my $self = shift;
    my $sink = shift;
    for (keys %{$self->{feeders}}) {
        my $feeder = $self->{feeders}->{$_};
        if ($feeder->canread()) {
            $sink->write($feeder->readline());
            return;
        }
    }
}

sub feederProvideData {
    my $self = shift;
#     print "feederProvideData\n";
    my $feeder = shift;
    my $line = undef;
    for (keys %{$self->{sinks}}) {
        my $sink = $self->{sinks}->{$_};
        if ($sink->canwrite()) {
            if (!defined $line) {
                $line = $feeder->readline();
#                 printf "feeder readline '%s'\n", $line;
            }
            $sink->write($line);
        }
    }
}

sub broadcast {
    my $self = shift;
}

1;
