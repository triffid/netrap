package EventDispatch;

use strict;

use Data::Dumper;
use Carp;
use Scalar::Util qw(blessed);

our @events;

sub runEvents {
    while (@events) {
        my ($eventName, $function, $instance, $self, $args) = @{shift @events};
        my @args = @{$args};
#         printf "%s->%s:%s(%s)\n", $instance, $function, $eventName, $self;
        $function->($instance, $self, @args);
#         print "ok\n";
    }
#     print "end events\n";
}

sub new {
    my $class = shift;

    my $self = {
        Events => {
        },
    };

    for (@_) {
        $self->{Events}->{$_} = [];
    }

    bless $self, $class;

    return $self;
}

sub init {
    my $self = shift;
    $self->{Events} = {}
        unless exists $self->{Events};
    return $self;
}

sub addEvent {
    my $self = shift;

    $self->{Events} = {}
        unless exists $self->{Events};

    for my $eventName (@_) {
        $self->{Events}->{$eventName} = []
            unless exists $self->{Events}->{$eventName};
    }
}

sub delEvent {
    my $self = shift;
    my $eventName = shift;

    $self->{Events} = {}
        unless exists $self->{Events};

    delete $self->{Events}->{$eventName};
}

sub addReceiver {
    my $self = shift;
    my $eventName = shift;
    my ($instance, $function) = @_;

    croak sprintf('addReceiver expects $blessed, $CODE. Got %s, %s', $instance, $function) if !blessed($instance) || ref($function) ne 'CODE';

    $self->{Events} = {}
        unless exists $self->{Events};

    warn sprintf "Event $eventName not found in %s! Candidates are: %s", $self, join ' ', keys %{$self->{Events}}
        unless exists $self->{Events}->{$eventName};

#     printf "%s:addReceiver \"%s\" %s %s\n", $self->describe(), $eventName, $instance->describe(), $function;

    if (grep { $_->[0] == $instance && $_->[1] == $function } @{$self->{Events}->{$eventName}}) {
        printf "Attempt to add duplicate receiver %s %s to Event %s on %s\n", $instance, $function, $eventName, $self->describe();
        return;
    }

    push @{$self->{Events}->{$eventName}}, [$instance, $function];
}

sub removeReceiver {
    my $self = shift;
    my $eventName = shift;
    my ($instance, $function) = @_;

#     printf "%s:remReceiver \"%s\" %s %s\n", $self->describe(), $eventName, $instance->describe(), $function;

    my @indices = grep {$self->{Events}->{$eventName}->[$_]->[0] == $instance && $self->{Events}->{$eventName}->[$_]->[1] == $function} 0..$#{$self->{Events}->{$eventName}};

#     printf "indices: [%s]\n", join ",", @indices;

    $self->{Events} = {}
        unless exists $self->{Events};

#     printf "Got %d, ", scalar @{$self->{Events}->{$eventName}};

    for (sort {$b cmp $a} @indices) {
#         printf "%s == %s and %s == %s?\n", $self->{Events}->{$eventName}->[$_]->[0], $instance, $self->{Events}->{$eventName}->[$_]->[1], $function;
        if ($self->{Events}->{$eventName}->[$_]->[0] eq $instance && $self->{Events}->{$eventName}->[$_]->[1] eq $function) {
            splice @{$self->{Events}->{$eventName}}, $_, 1;
        }
        else {
#             printf "WTF? %s != %s, or %s != %s!\n", $self->{Events}->{$eventName}->[$_]->[0], $instance, $self->{Events}->{$eventName}->[$_]->[1], $function;
        }
    }

#     printf "%d left\n", scalar @{$self->{Events}->{$eventName}};

    return scalar @indices;
}

sub cullReceivers {
    my $self = shift;
    my $eventName = shift;

    $self->{Events} = {}
        unless exists $self->{Events};

    my $r = 0;
    $r = @{$self->{Events}->{$eventName}} if ref($self->{Events}->{$eventName}) eq 'ARRAY';

    $self->{Events}->{$eventName} = [];

    return $r;
}

sub hasEvent {
    my $self = shift;
    my $eventName = shift;

    return defined $self->{Events}->{$eventName};
}

sub fireEvent {
    my $self = shift;
    my $eventName = shift;

    $self->{Events} = {}
        unless exists $self->{Events};

    return unless $self->{Events}->{$eventName} && ref($self->{Events}->{$eventName}) eq 'ARRAY';

#     printf "%s fires %s\n", $self->describe(), $eventName;

#     print Dumper $self->{Events}->{$eventName};

    my $nreceivers = 0;
    my @copy = @{$self->{Events}->{$eventName}};
    for (@copy) {
        my ($instance, $function) = @{$_};
        $nreceivers++;
#         printf "Receives:[%s->%s] ", $function, $instance->describe();
#         $function->($instance, $self, @_);
        push @events, [$eventName, $function, $instance, $self, [@_]];
    }
#     printf "\nEvent distributed to %d with %d receivers\n", $nreceivers, scalar(@{$self->{Events}->{$eventName}});
    return $nreceivers;
}

1;
