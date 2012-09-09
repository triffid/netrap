package Netrap::Socket::File;

use Netrap::Socket;

our %FileSockets;

@ISA = qw(Netrap::Socket);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self = $class->SUPER::new(@_);

    bless $self, $class;

    $FileSockets{$self->{sock}} = $self;

    return $self;
}

1;
