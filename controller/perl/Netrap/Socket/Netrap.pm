package Netrap::Socket::Netrap;

use Netrap::Socket;

our %NetrapSockets;

@ISA = qw(Netrap::Socket);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self = $class->SUPER::new(@_);

    bless $self, $class;

    $NetrapSockets{$self->{sock}} = $self;

    return $self;
}

1;
