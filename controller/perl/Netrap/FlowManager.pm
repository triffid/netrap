package Netrap::FlowManager;

use strict;
use vars qw(@ISA);

use Data::Dumper;
use IO::Select;
use Netrap::Socket;
use List::Util qw(first);

@ISA = qw(EventDispatch);

sub _addFeeder {
    my $self = shift;
    my $feeder = shift or die;
    if (!exists $self->{feeders}->{$feeder}) {
        $self->{feeders}->{$feeder} = $feeder;
        push @{$self->{feederOrder}}, "$feeder";
        $feeder->addReceiver('Read',  $self, $self->can('feederProvideData')) unless $self->{frozen};
        $feeder->addReceiver('Close', $self, $self->can('removeFeeder'));
    }
}

sub _addSink {
    my $self = shift;
    my $sink = shift;
    if (!exists $self->{sinks}->{$sink}) {
        $self->{sinks}->{$sink} = $sink;
        push @{$self->{sinkOrder}}, "$sink";
        $sink->addReceiver('CanWrite', $self, $self->can('sinkRequestData')) unless $self->{frozen};
        $sink->addReceiver('Close', $self, $self->can('removeSink'));
    }
}

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self = {};

    bless $self, $class;

    $self->{ReadSelector} = $Netrap::Socket::ReadSelector;
    $self->{WriteSelector} = $Netrap::Socket::WriteSelector;
    $self->{ErrorSelector} = $Netrap::Socket::ErrorSelector;

    $self->addEvent('Complete');

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
        if ($sink) {
            $sink->removeReceiver('CanWrite', $self, $self->can('sinkRequestData')) unless $self->{frozen};
            $sink->removeReceiver('Close', $self, $self->can('removeSink'));
            my $index = first { $self->{sinkOrder}->[$_] eq "$sink" } 0..$#{$self->{sinkOrder}};
            splice @{$self->{sinkOrder}}, $index, 1
                if defined $index;
        }
        delete $self->{sinks}->{$sink};
    }
}

sub sinkRequestData {
    my $self = shift;
    my $sink = shift;

#     printf "sinkRequestData\n";

#     print Dumper $self;

    return undef if $self->{frozen};

#     printf "sinkRequestData\n";

    my @l = @{$self->{feederOrder}};
    for (@l) {
        my $feeder = $self->{feeders}->{$_} or die Dumper \$self;
        if ($feeder->canread()) {
            my $data;
            my $length;
#             printf "%s can read; ", $feeder->describe();
            if ($feeder->raw()) {
                $data = $feeder->read($self->{maxdata} || 4096);
                $length = length($data);
            }
            else {
                $data = $feeder->readline(\$length);
            }
#             my $displaydata = $data;
#             $displaydata =~ s/([\x0-\x1A\x7E-\xFF])/sprintf "\\x%02X", ord $1/ge;
#             printf "%s provides %d: '%s'\n", $feeder->describe(), $length, $displaydata;
            if (defined $data && $length > 0) {
                $sink->write($data);
                $self->{datacount} += $length;
                if ($self->{maxdata}) {
                    if ($self->{datacount} >= $self->{maxdata}) {
                        $self->fireEvent('Complete');
                    }
#                     printf "Transferred %d of %d bytes\n", $self->{datacount}, $self->{maxdata};
                }
                push @{$self->{feederOrder}}, shift @{$self->{feederOrder}};
#                 printf "sinkRequestData: got data from feeder %s\n", $feeder;
                return $feeder;
            }
        }
        else {
#             printf "%s can't read\n", $feeder->describe();
#             print Dumper $feeder;
        }
    }
}

sub feederProvideData {
    my $self = shift;
    my $feeder = shift;

#     printf "feederProvideData\n";

    return undef if $self->{frozen};

    my $line = undef;
    my @l = @{$self->{sinkOrder}};
    my $sink;

    for (@l) {
        $sink = $self->{sinks}->{$_};
        if ($sink->canwrite()) {
            if (!defined $line) {
                my $length;
                if ($feeder->raw()) {
                    $line = $feeder->read($self->{maxdata} || 4096);
                    $length = length($line);
                }
                else {
                    $line = $feeder->readline(\$length);
                }
                if ($length) {
                    $self->{datacount} += $length;
                }
            }
#             my $displaydata = $line;
#             $displaydata =~ s/([\x0-\x1A\x80-\xFF])/sprintf "\\x%02X", ord $1/ge;
#             printf "%s provides '%s'\n", $feeder->describe(), $displaydata;
#             print Dumper $feeder;
            $sink->write($line);
#             printf "Wrote \"%s\" to %s\n", $line, $sink->describe();
            if ($self->{maxdata}) {
                if ($self->{datacount} >= $self->{maxdata}) {
                    $self->fireEvent('Complete');
                }
#                 printf "Transferred %d of %d bytes\n", $self->{datacount}, $self->{maxdata};
            }
            shift @{$self->{sinkOrder}};
            push @{$self->{sinkOrder}}, $_;
            return $sink;
        }
    }
#     printf "feederProvideData return\n";
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

sub dataCount {
    my $self = shift;
    return $self->{datacount} or 0;
}

sub resetData {
    my $self = shift;
    $self->{datacount} = 0;
}

sub maxData {
    my $self = shift;
    my $newmax = shift;

    if (defined $newmax) {
        $self->{maxdata} = $newmax;
    }

    return $self->{maxdata};
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
