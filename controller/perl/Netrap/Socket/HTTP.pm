package Netrap::Socket::HTTP;

use strict;
use vars qw(@ISA);

use Netrap::Socket;
use Netrap::Parse;
use JSON::PP;

use Data::Dumper;

my %HTTPSockets;

my %mime_types;

@ISA = qw(Netrap::Socket);

use constant {
    STATE_START => 0,
    STATE_GET_HEADERS => 1,
    STATE_GET_DATA => 2,
    STATE_SEND_DATA => 3,
};

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

    $self->{headers}    = {};
    $self->{state}      = 0;

    bless $self, $class;

    if (keys(%mime_types) == 0) {
        if (open M, "< /etc/mime.types") {
            for (<M>) {
                if (m#^([\w\-]+/\S+)\s*(.*?)$#) {
                    my ($mime, $extensions) = ($1, $2);
                    for (split /\s+/, $extensions) {
                        $mime_types{$_} = $mime;
                    }
                }
            }
            close M;
        }
    }

    $Netrap::Socket::HTTP::HTTPSockets->{$self->{sock}} = $self;

    return $self;
}

sub ReadSelectorCallback {
    my $self = shift;
    $self->SUPER::ReadSelectorCallback();

    while ($self->canread()) {
#         printf "%s: STATE is %d\n", $self->{name}, $self->{state};
        # state 0 - wait for HTTP request
        if ($self->{state} == STATE_START) {
            my $line = $self->readline();
#             printf "\tRead: \t%s\n", $line;
            if ($line =~ m#^(GET|POST|HEAD|OPTION)\s+(/\S*)\s+HTTP/(\d+(\.\d+)?)$#) {
                $self->{headers}->{method} = $1;
                $self->{headers}->{url} = $2;
                $self->{headers}->{httpversion} = $3;
                $self->{state} = STATE_GET_HEADERS;
            }
        }
        # state 1 - collect headers
        elsif ($self->{state} == STATE_GET_HEADERS) {
            my $line = $self->readline();
#             printf "\tRead: \t%s\n", $line;
            if ($line =~ m#^([\w\-\_]+)\s*:\s*(.*?)$#) {
                $self->{headers}->{lc $1} = $2;
            }
            if ($line =~ /^$/) {
                return if $self->processHTTPRequest();
            }
        }
        # state 2 - receive data
        elsif ($self->{state} == STATE_GET_DATA) {
            $self->{content} .= $self->read(4096);
#             printf "Received %d bytes\n", length($self->{content});
#             die Dumper \$self;
            if (length($self->{content}) >= $self->{headers}->{"content-length"}) {
                return if $self->processHTTPRequest();
            }
        }
        else {
            return;
        }
    }
}

sub WriteSelectorCallback {
    my $self = shift;

    my $written = $self->SUPER::WriteSelectorCallback();

#     printf "\tWrite:\t%s", $written;

    if ($self->{flowmanager}) {
        $self->{flowmanager}->sinkRequestData($self);
    }
}

sub sendHeader {
    my $self = shift;

    $self->raw(0);
    $self->write(sprintf "HTTP/1.1 %s %s", $self->{headers}->{responsecode}, $self->{headers}->{responsedesc});
    for (keys %{$self->{responseheaders}}) {
        $self->write(sprintf "%s: %s", $_, $self->{responseheaders}->{$_});
    }
    $self->write("");
}

sub processHTTPRequest {
    my $self = shift;

    my $url = $self->{headers}->{url};

    $url = '/index.html' if $url eq '/';

#     my $returncode = 200;
    $self->{headers}->{responsecode} = 200;
    $self->{headers}->{responsedesc} = "OK";
    $self->{responseheaders} = {};
    $self->{responseheaders}->{'Content-Type'} = "text/html";
    $self->{responseheaders}->{'Connection'} = "keep-alive";

    my $content = "";

    if ($url =~ m#\.\./# || $url =~ m#/\.\.#) {
        $self->{headers}->{responsecode} = 400;
        $self->{headers}->{responsedesc} = "Bad Request";
    }
    else {
#         die Dumper \$self;
        if (defined $self->{headers}->{"content-length"}) {
            if (length($self->{content}) < $self->{headers}->{"content-length"}) {
#                 print "Waiting for data\n";
                $self->{state} = STATE_GET_DATA;
                $self->{content} = "";
                $self->raw(1);
#                 return 0;
            }
        }

        if ($url =~ m#^/json/(.*)#) {
            my $jsonurl = $1;
            return 0 if (lc $self->{headers}->{'content-type'} eq 'application/json') && (length($self->{content}) < $self->{headers}->{"content-length"});
            $self->{responseheaders}->{'Content-Type'} = 'application/json';
            if ($jsonurl =~ m#^(\w+)-(\w+)$#) {
                my ($target, $action) = ($1, $2);
                printf "Parsing %s:%s\n", $target, $action, $self->{content};
#                 die Dumper Netrap::Parse::actions($target, $action);
                if (Netrap::Parse::actions($target, $action)) {
                    my $object;
                    eval { $object = decode_json($self->{content}) };
                    printf "Got %s\n", Data::Dumper->Dump([$object], [qw'json']) if $object;
                    $object = {%{$object // {}}, 'target' => $target, 'action' => $action, 'status' => 'OK' };
                    my $response = Netrap::Parse::actions($target, $action)->($object) // {%{$object}, 'status' => 'error', 'error' => 'no handler'};
                    $content = encode_json $response;
                }
            }
        }
        else {
            $content = sprintf "<html><body><h1>404 File Not Found</h1><p>%s</p></body></html>", $!;
            $self->{headers}->{responsecode} = 404;
            $self->{headers}->{responsedesc} = "Not Found";
            my $local = "./html".$url;
            if (-r $local && ! -d $local) {
                my $filesocket = new Netrap::Socket::File($local);
                if ($filesocket) {
                    if ($local =~ /\.(\w+)$/ && $mime_types{$1}) {
                        $self->{responseheaders}->{'Content-Type'} = $mime_types{$1};
                    }
                    else {
                        # same as qx// except we don't havae to sanitise the filename
                        my $pid = open(KID, "-|");
                        if (defined $pid) {
                            if ($pid) {
                                my $mime = <KID>;
                                close KID;
                                if ($mime =~ m#^[\w\-]+/[\w\-]+$#) {
                                    $self->{responseheaders}->{'Content-Type'} = $mime;
                                    die "$local: $mime";
                                }
                            }
                            else {
                                exec 'file', '--mime-types', '-b', $local or die $!;
                            }
                        }
                    }
                    $filesocket->raw(1);
                    my $fm = new Netrap::FlowManager();
                    $self->{responseheaders}->{'Content-Length'} = $filesocket->length();
                    $fm->addSink($self);
                    $fm->addFeeder($filesocket);
                    undef $content;
                    $self->{headers}->{responsecode} = 200;
                    $self->{headers}->{responsedesc} = 'OK';
                    $filesocket->addReceiver('Close', $self, \&Netrap::Socket::HTTP::fileSendComplete);

#                     $self->write(sprintf "HTTP/1.1 %s %s", $self->{headers}->{responsecode}, $self->{headers}->{responsedesc});
#                     for (keys %{$self->{responseheaders}}) {
#                         $self->write(sprintf "%s: %s", $_, $self->{responseheaders}->{$_});
#                     }
#                     $self->write("");
                    $self->sendHeader();
                    $self->{state} = STATE_SEND_DATA;
                    $self->raw(1);

                    my $log = "^remoteaddr;:^remoteport;\t^method; ^url; ^responsecode; ^size;\n";
                    $log =~ s/\^(\w+)\;/$self->{headers}->{$1} || $self->{$1}/eg;
                    print $log;
                    return;
                }
            }
        }
    }

    if ($self->{headers}->{responsecode} > 299) {
        $content = sprintf "<html><body><h1>%d %s</h1><p>%s</p></body></html>", $self->{headers}->{responsecode}, $self->{headers}->{responsedesc}, $self->{headers}->{responsedesc}
            unless $content;
    }

    $self->{responseheaders}->{'Content-Length'} = length($content) unless $self->{responseheaders}->{'Content-Length'};
    $self->sendHeader();
    $self->write($content) if $content;

    $self->{state} = STATE_START;

    my $log = "^remoteaddr;:^remoteport;\t^method; ^url; ^responsecode; ^size;\n";
    $log =~ s/\^(\w+)\;/$self->{headers}->{$1} || $self->{$1}/eg;
    print $log;

    return 1;
}

sub processHTTPData() {
    my $self = shift;

}

sub fileSendComplete() {
    my $self = shift;
#     printf "%s: File Send Complete %d\n", $self, $self->canread();
    $self->raw(0);
    $self->{headers} = {};
    $self->{state} = STATE_START;
    delete $self->{flowmanager};
}

sub checkclose() {
    my $self = shift;
    if ($self->SUPER::checkclose()) {
#         printf "Connection from %s closed\n", $self->{name};
    }
}

1;
