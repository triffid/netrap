package Netrap::Socket::Netrap;

use strict;
use vars qw(@ISA);

use Netrap::Socket;
use Netrap::Parse;

use Data::Dumper;

our %NetrapSockets;

@ISA = qw(Netrap::Socket);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $sock = shift;
    my $address = shift;

    my $self = $class->SUPER::new($sock);

    $self->{address}    = $address;
    $self->{remoteaddr} = join(".", (unpack('SnCCCC', $address))[2,3,4,5]);
    $self->{remoteport} = (unpack('SnCCCC', $address))[1];
    $self->{name}       = sprintf "%s:%d", $self->{remoteaddr}, $self->{remoteport};

    $self->{printer} = undef;
    $self->addEvent('Gcode');

    bless $self, $class;

    $NetrapSockets{$self->{sock}} = $self;

    return $self;
}

sub describe {
    my $self = shift;
    return sprintf "[Socket Netrap %s]", $self->{name};
}

sub ReadSelectorCallback {
    my $self = shift;

#     print "Netrap:ReadCallback\n";

    $self->SUPER::ReadSelectorCallback(1);

    my $parsed = 0;
    while ($self->canread()) {
        $parsed = 0;
#         print "canread\n";
        my $line = $self->peekline();
#         printf "peek: %s\n", $line;
        for ($line) {
            /^([a-z]{3,})\s+([a-z]{3,}?)s?(\s+(.*?))?$/ && do {
                $line = $self->readline();
                my ($target, $action, $data) = ($2, $1, $4);
                if (my $callback = Netrap::Parse::actions($target, $action)) {
#                     printf "callback\n";
                    if (my $result = $callback->($self, $data)) {
#                         printf "%s:%s(%s)!\n", $target, $action, $data;
#                         print Dumper \$result;
                        if (ref($result)) {
                            my $data = new Data::Dumper([$result]);
                            my $resultstr = "ok ";
                            $data->Pair(':');
                            $data->Quotekeys(1);
                            $data->Deepcopy(1);
                            $data->Terse(1);
                            $data->Useqq(1);
                            $data->Indent(0);
                            $data->Sortkeys(1);
                            $resultstr = "ok ".$data->Dump();
                            $self->write($resultstr);
                        }
                        else {
                            print "$result\n";
                            $self->write($result);
                        }
                        $parsed = 1;
                    }
                }
                if ($parsed == 0) {
                    $self->write("err Unrecognized command: $target::$action");
                    $parsed = 2;
                }
            };
            /^exit$/ && do {
                $line = $self->readline();
                $self->write("ok bye");
                $self->close();
                $parsed = 1;
            };
        }
        if ($parsed == 0) {
            if ($self->fireEvent('Read') == 0) {
                $self->readline();
                $self->write('error: no printer selected');
            }
            last;
        }
    }
}

sub checkclose {
    my $self = shift;

    my $r = $self->SUPER::checkclose(@_);

    if ($r == 1) {
        delete $NetrapSockets{$self};
    }

    return $r;
}

1;
