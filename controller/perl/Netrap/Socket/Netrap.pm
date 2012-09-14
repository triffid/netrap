package Netrap::Socket::Netrap;

use strict;

use Netrap::Socket;

our %NetrapSockets;

@ISA = qw(Netrap::Socket);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self = $class->SUPER::new(@_);

    $self->{printer} = undef;

    bless $self, $class;

    $NetrapSockets{$self->{sock}} = $self;

    return $self;
}

sub ReadSelectorCallback {
    my $self = shift;

    $self->SUPER::ReadSelectorCallback();

    if ($self->canread()) {

    }
}

1;
