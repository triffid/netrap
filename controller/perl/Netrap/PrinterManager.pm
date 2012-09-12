package Netrap::PrinterManager;

use strict;

use Netrap::FlowManager;

@ISA = qw(Netrap::FlowManager);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self = $class->SUPER::new(@_);

    $self->{lastFeeder} = undef;

    bless $self, $class;
    return $self;
}

sub addSink {
    my $self = shift;

    my $sink = shift;

    $self->SUPER->addSink($self, $sink);

    $sink->addReceiver('PrinterResponse', $self, \&Netrap::PrinterManager::printerResponse);
    $sink->addReceiver('Token', $self, \&Netrap::PrinterManager::Token);
}

sub feederProvideData {
    my $self = shift;

    my $feeder = shift;
    $self->SUPER::feederProvideData($feeder);
    $self->{lastFeeder} = "$feeder";
}

sub sinkRequestData {
    my $self = shift;

    my $feeder = $self->SUPER::sinkRequestData(@_);
    $self->{lastFeeder} = "$feeder";
}

sub printerResponse {
    my $self = shift;
    my $printer = shift;
    my $line = shift;
    if ($self->{lastFeeder}) {
        $self->{lastFeeder}->write($line);
    }
}

sub printerToken {
    my $self = shift;
    my $printer = shift;

    $self->{lastFeeder} = undef;

    $self->sinkRequestData($printer);
}

1;