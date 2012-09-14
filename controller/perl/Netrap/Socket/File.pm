package Netrap::Socket::File;

use strict;
use vars qw(@ISA);

use Netrap::Socket;

our %FileSockets;

@ISA = qw(Netrap::Socket);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $filename = shift;
    my $sock;

    $sock = new IO::File($filename) or return undef;

    my $self = $class->SUPER::new($sock);

    $self->{filename} = $filename;
    $self->{length} = -s $filename;

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
    if ($r == 0) {
        $self->{ReadSelector}->add($self->{sock});
        $self->{close} = 1;
    }
}

sub length {
    my $self = shift;
    return $self->{length};
}

sub tell {
    my $self = shift;
    return tell $self->{sock};
}

sub remaining {
    my $self = shift;
    return $self->{length} - (tell $self->{sock});
}

1;
