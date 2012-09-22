package Netrap::Socket::File;

use strict;
use vars qw(@ISA);

use Fcntl qw(SEEK_SET);

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
    $self->{frozen} = 0;

    bless $self, $class;

    $FileSockets{$self->{sock}} = $self;

    return $self;
}

sub describe {
    my $self = shift;
    return sprintf "[Socket FILE %s]", $self->{filename};
}

sub canread {
    my $self = shift;

    return 0 if $self->{close};
    return 0 if $self->{frozen};

    return $self->SUPER::canread(@_);
}

sub ReadSelectorCallback {
    my $self = shift;
    return if $self->{frozen};
    my $r = $self->SUPER::ReadSelectorCallback(@_);
    if ($r == 0) {
        $self->close();
    }
}

sub write {
    my $self = shift;
    return;
}

sub seek {
    my $self = shift;
    my $position = shift;
    seek $self->{sock}, $position, SEEK_SET;
    $self->flushrx();
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

sub freeze {
    my $self = shift;
    my $freeze = shift;

    if (defined $freeze && (($freeze)?1:0) != $self->{frozen}) {
        if ($freeze) {
            $self->{ReadSelector}->remove($self->{sock});
            $self->{frozen} = 1;
        }
        else {
            $self->{frozen} = 0;
            $self->{ReadSelector}->add($self->{sock});
            if ($self->canread()) {
                $self->fireEvent('Read');
            }
        }
    }

    return $self->{frozen};
}

1;
