package Netrap::FlowManager;

use IO::Select;
use Netrap::Socket;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new();

    $self->{ReadSelector} = $Netrap::Socket::ReadSelector;
    $self->{WriteSelector} = $Netrap::Socket::WriteSelector;
    $self->{ErrorSelector} = $Netrap::Socket::ErrorSelector;

    $self->{broadcast} = 0;
    $self->{feeders} = {};
    $self->{sinks} = {};

    bless $self, $class;
    return $self;
}

sub addFeeder {
    my $self = shift;
    while (@_) {
        my $feeder = shift;
        $self->{feeders}->{$feeder} = $feeder;
        if ($feeder->canread()) {
            $self->feederProvideData();
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
    my $feeder = shift;
    my $line = undef;
    for (keys %{$self->{sinks}}) {
        my $sink = $self->{sinks}->{$_};
        if ($sink->canwrite()) {
            if (!defined $line) {
                $line = $feeder->readline();
            }
            $sink->write($line);
        }
    }
}

sub broadcast {
    my $self = shift;
}

1;
