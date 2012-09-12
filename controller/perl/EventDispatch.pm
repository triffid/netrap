package EventDispatch;

use strict;

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

    die sprintf "Event $eventName not found in %s! Candidates are: %s", $self, join ' ', keys %{$self->{Events}}
        unless exists $self->{Events}->{$eventName};

    push @{$self->{Events}->{$eventName}}, [$instance, $function];
}

sub removeReceiver {
    my $self = shift;
    my $eventName = shift;
    my ($instance, $function) = @_;

    my @indices = grep {$self->{Events}->{$eventName}->[0] == $instance && $self->{Events}->{$eventName}->[1] == $function} 0..$#{$self->{Events}->{$eventName}};

    $self->{Events} = {}
        unless exists $self->{Events};

    for (sort {$b cmp $a} @indices) {
        splice @{$self->{Events}->{$eventName}}, $_, 1;
    }

    return scalar @indices;
}

sub fireEvent {
    my $self = shift;
    my $eventName = shift;

    $self->{Events} = {}
        unless exists $self->{Events};

    for (@{$self->{Events}->{$eventName}}) {
        my ($instance, $function) = @{$_};
        $function->($instance, @_);
    }
}

1;
