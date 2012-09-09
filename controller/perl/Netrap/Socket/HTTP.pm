package Netrap::Socket::HTTP;

use Netrap::Socket;

our %HTTPSockets;

@ISA = qw(Netrap::Socket);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self = $class->SUPER::new(@_);

    $self->{headers} = {};
    $self->{state} = 0;

    bless $self, $class;

    $HTTPSockets->{$self->{sock}) = $self;

    return $self;
}

sub ReadSelectorCallback {
    my $self = shift;
    $self->SUPER::ReadSelectorCallback($self);

    while ($self->canread()) {
        my $line = $self->readline();
        # state 0 - wait for HTTP request
        if ($self->{state} == 0) {
            if ($line =~ m#^(GET|POST|HEAD|OPTION)\s+(/\S+)\s+HTTP/(\d+(\.\d+)?)$#) {
                $self->{headers}->{method} = $1;
                $self->{headers}->{url} = $2;
                $self->{headers}->{httpversion} = $3;
                $self->{state} = 1;
            }
        }
        # state 1 - collect headers
        elif ($self->{state} == 1) {
            if ($line =~ m#^([\w\-\_]+)\s*:\s*.*?$#) {
                $self->{headers}->{lc $1} = $2;
            }
            if ($line =~ /^$/) {
                $self->{state} = 2;
                if (exists $self->{headers}->{"content-length"}) {
                    $self->{headers}->{"content-remaining"} = $self->{headers}->{"content-length"};
                    $self->raw(1);
                }
                else {
                    $self->processHTTPRequest();
                }
            }
        }
        # state 2 - receive data
        elif ($self->{state} == 2) {
            $self->{content} = $line;
            if (length($self->{content}) >= $self->{headers}->{"content-length"}) {
                $self->processHTTPRequest();
            }
        }
    }
}

sub WriteSelectorCallback {
    my $self = shift;
    $self->SUPER::WriteSelectorCallback();

    if ($self->{flowmanager}) {
        $self->{flowmanager}->sinkRequestData($self);
    }
}

sub processHTTPRequest() {
    my $self = shift;

    my $url = $self->{headers}->{url};

    my $returncode = 200;

    if ($url =~ m#\.\./# || $url =~ m#/\.\.#) {
        $returncode = 400;
        $url = "/400.html";
    }

    if ($url =~ m#^/json/(.*)#) {
    }
    else {
        my $local = ".".$url;
        if (-r $local) {
            my $file;
            if (open $file, '<', $local) {
                my $filesocket = new Netrap::Socket::File($file);
                my $fm = new Netrap::FlowManager();
                $fm->addSink($self);
                $fm->addFeeder($filesocket);
            }
        }
    }
}

1;
