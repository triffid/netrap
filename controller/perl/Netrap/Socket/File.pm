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
    my $mode = shift or 'r';
    my $sock;

    $sock = new IO::File($filename, $mode) or return undef;

    my $self = $class->SUPER::new($sock);

    $self->{filename} = $filename;
    $self->{length} = -s $filename;
    $self->{frozen} = 0;
    $self->{read}  = ($mode =~ /[r\+\<]/ )?1:0;
    $self->{write} = ($mode =~ /[w\+\>a]/)?1:0;

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
    if (!$self->{read} && !$self->{close}) {
        $self->{ReadSelector}->remove($self->{sock});
        return;
    }
    my $r = $self->SUPER::ReadSelectorCallback(@_);
    if ($r == 0) {
        $self->close();
    }
}

sub WriteSelectorCallback {
    my $self = shift;
    printf "%s: WriteCallback %d %d %d\n", $self->describe(), length($self->{txbuffer}), scalar(@{$self->{txqueue}}), $self->{raw};
    return $self->SUPER::WriteSelectorCallback(@_);
}

sub write {
    my $self = shift;
    return unless $self->{write};
    print "File:Write\n";
    return $self->SUPER::write(@_);
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

sub readmode {
    my $self = shift;

    my $newflag = shift;

    if (defined $newflag) {
        $self->{read} = $newflag?1:0;
        if ($self->{read}) {
            $self->{ReadSelector}->add($self->{sock});
        }
        else {
            $self->{ReadSelector}->remove($self->{sock});
        }
    }

    return $self->{read};
}

sub writemode {
    my $self = shift;

    my $newflag = shift;

    if (defined $newflag) {
        $self->{write} = $newflag?1:0;
        if ($self->{write}) {
            $self->{WriteSelector}->add($self->{sock});
        }
        else {
            $self->{WriteSelector}->remove($self->{sock});
        }
    }

    return $self->{write};
}

sub checkclose {
    my $self = shift;

    my $r = $self->SUPER::checkclose(@_);

    if ($r == 1) {
        delete $FileSockets{$self};
    }

    return $r;
}

1;
