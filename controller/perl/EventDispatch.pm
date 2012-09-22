package EventDispatch;

use strict;

use Data::Dumper;

our @events;

sub runEvents {
    while (@events) {
        my ($function, $instance, $self, $args) = @{shift @events};
        my @args = @{$args};
        $function->($instance, $self, @args);
    }
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

    $self->{Events} = {}
        unless exists $self->{Events};

    warn sprintf "Event $eventName not found in %s! Candidates are: %s", $self, join ' ', keys %{$self->{Events}}
        unless exists $self->{Events}->{$eventName};

#     printf "%s:addReceiver \"%s\" %s %s\n", $self->describe(), $eventName, $instance->describe(), $function;

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

sub fireEvent {
    my $self = shift;
    my $eventName = shift;

    $self->{Events} = {}
        unless exists $self->{Events};

#     printf "%s fires %s; ", $self->describe(), $eventName;

#     print Dumper $self->{Events}->{$eventName};

    my $nreceivers = 0;
    my @copy = @{$self->{Events}->{$eventName}};
    for (@copy) {
        my ($instance, $function) = @{$_};
        $nreceivers++;
#         printf "Receives:[%s->%s] ", $function, $instance->describe();
#         $function->($instance, $self, @_);
        push @events, [$function, $instance, $self, [@_]];
    }
#     printf "\nEvent distributed to %d with %d receivers\n", $nreceivers, scalar(@{$self->{Events}->{$eventName}});
    return $nreceivers;
}

1;
