package Netrap::PrinterManager;

use strict;
use vars qw(@ISA);

use Netrap::FlowManager;

use Data::Dumper;

@ISA = qw(Netrap::FlowManager);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self = $class->SUPER::new(@_);

    $self->{lastFeeder} = undef;

    bless $self, $class;
    return $self;
}

sub describe {
    my $self = shift;
#     die Dumper \$self;
    return sprintf "[PrinterManager for %s: %d feeders]", $self->{sinks}->{$self->{sinkOrder}->[0]}->{name}, scalar(@{$self->{feederOrder}});
}

sub addSink {
    my $self = shift;
    my $sink = shift;

    $self->SUPER::addSink($sink);

    $sink->addReceiver('PrinterResponse', $self, $self->can('printerResponse'));
    $sink->addReceiver('Token', $self, $self->can('printerToken'));
}

sub feederProvideData {
    my $self = shift;

#     print "PrinterManager: feederProvideData\n";

    my $feeder = shift;
    $self->SUPER::feederProvideData($feeder, @_);
    $self->{lastFeeder} = $feeder;

#     printf "feederProvideData: lastFeeder is %s\n", $self->{lastFeeder};
}

sub removeFeeder {
    my $self = shift;
    my $feeder = shift;

    return $self->SUPER::removeFeeder($feeder, @_);
}

sub sinkRequestData {
    my $self = shift;

#     print "PrinterManager: sinkRequestData\n";

    my $feeder = $self->SUPER::sinkRequestData(@_);
    $self->{lastFeeder} = $feeder if $feeder;

#     printf "sinkRequestData: lastFeeder is %s\n", $self->{lastFeeder};
}

sub printerResponse {
    my $self = shift;
    my $printer = shift;
    my $line = shift;
    if ($self->{lastFeeder}) {
#         printf "Last feeder is %d, sending '%s'\n", $self->{lastFeeder}->describe(), $line;
        $self->{lastFeeder}->write($line);
    }
    else {
#         printf "lastFeeder is undefined\n";
    }
#     printf "printerResponse: lastFeeder is %s\n", $self->{lastFeeder};
}

sub printerToken {
    my $self = shift;
    my $printer = shift;

    $self->{lastFeeder} = undef;

#     printf "printerToken: lastFeeder is %s\n", $self->{lastFeeder};

    $self->sinkRequestData($printer);
}

1;