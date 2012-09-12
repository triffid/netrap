package Netrap::Socket::File;

use strict;
use vars qw(@ISA);

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

sub canread {
    my $self = shift;

    return 0 if $self->{close};

    return $self->SUPER::canread(@_);
}

sub ReadSelectorCallback {
    my $self = shift;
    my $r = $self->SUPER::ReadSelectorCallback(@_);
#     printf "File::ReadSelector sees %d read\n", $r;
    if ($r == 0) {
        $self->{ReadSelector}->add($self->{sock});
        $self->{close} = 1;
    }
}

1;
