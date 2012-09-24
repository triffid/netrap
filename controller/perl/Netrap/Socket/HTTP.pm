package Netrap::Socket::HTTP;

use strict;
use vars qw(@ISA);

use Netrap::Socket;
use Netrap::Parse;
use JSON::PP;

use Data::Dumper;

use constant {
    STATE_START => 0,
    STATE_GET_HEADERS => 1,
    STATE_GET_DATA => 2,
    STATE_SEND_DATA => 3,
};

our %HTTPSockets;

my %mime_types;

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

    $self->{headers}    = {};
    $self->{state}      = STATE_START;

    bless $self, $class;

    $self->addEvent('GotHeader');
    $self->addEvent('GotSomeData');
    $self->addEvent('GotAllData');
#     $self->addEvent('WroteSomeData');
    $self->addEvent('RequestComplete');

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

    $HTTPSockets{$self->{sock}} = $self;

    return $self;
}

sub describe {
    my $self = shift;
    return sprintf "[Socket HTTP %s]", $self->{name};
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
            if ($line =~ m#^(GET|POST|HEAD)\s+(/\S*)\s+HTTP/(\d+(\.\d+)?)$#) {
                $self->{headers}->{method} = $1;
                $self->{headers}->{url} = $2;
                $self->{headers}->{httpversion} = $3;
                $self->{state} = STATE_GET_HEADERS;
            }
            else {
#                 die Dumper \$line;
                printf "Bad request from %s '%s', closing\n", $self->describe(), $line;
                $self->close();
                $self->flushrx();
                return;
            }
        }
        # state 1 - collect headers
        elsif ($self->{state} == STATE_GET_HEADERS) {
            my $line = $self->readline();
#             printf "\tRead: \t%s\n", $line;
            if ($line =~ m#^([\w\-\_]+)\s*:\s*(.*?)$#) {
                $self->{headers}->{lc $1} = $2;
            }
            elsif ($line =~ /^$/) {
                $self->fireEvent('GotHeader');
                return if $self->processHTTPRequest();
            }
            else {
                $self->close();
            }
        }
        # state 2 - receive data
        elsif ($self->{state} == STATE_GET_DATA) {
            return if $self->{uploading};

            my $read = $self->read(4096);
            $self->{content} .= $read;
#             printf "Received %d bytes\n", length($self->{content});
#             die Dumper \$self;
            $self->{remaining} -= length($read);
            if ($self->{remaining} <= 0) {
                $self->fireEvent('GotAllData');
                return if $self->processHTTPRequest();
            }
            else {
                $self->fireEvent('GotSomeData');
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

    if ($self->canwrite() && $self->{FileSendFlowManager}) {
        $self->{FileSendFlowManager}->sinkRequestData($self);
    }
}

sub sendHeader {
    my $self = shift;

    return undef if $self->{headers}->{HeaderSent};

    $self->raw(0);
    $self->write(sprintf "HTTP/1.1 %s %s", $self->{headers}->{responsecode}, $self->{headers}->{responsedesc});
    $self->{responseheaders}->{"Connection"} = $self->{headers}->{"connection"} unless $self->{responseheaders}->{"Connection"};
    $self->{responseheaders}->{"Connection"} = 'close' unless defined $self->{responseheaders}->{'Content-Length'} && $self->{headers}->{"connection"} =~ /keep-alive/i;
    for (keys %{$self->{responseheaders}}) {
        $self->write(sprintf "%s: %s", $_, $self->{responseheaders}->{$_});
    }
    $self->write("");
    $self->{headers}->{HeaderSent} = 1;
    return 1;
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
#     $self->{responseheaders}->{'Connection'} = "keep-alive";

    my $content = "";
    my %object;

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

        %object = (%{$self->{headers}});
        if ($url =~ s/\?(.*)//) {
            my $args = $1;
            my @pairs = split /\&/, $args;
            for (@pairs) {
                my $key = $_;
                my $value;
                $value = $1 if $key =~ s/=(.*)//;
                $key =~ s/%([0-9A-F]{2})/chr hex $1/eg;
                $value =~ s/%([0-9A-F]{2})/chr hex $1/eg;
                if ($object{$key}) {
                    if (ref($object{$key}) eq 'ARRAY') {
                        push @{$object{$key}}, $value;
                    }
                    else {
                        $object{$key} = [$object{$key}, $value];
                    }
                }
                else {
                    $object{$key} = $value;
                }
            }
        }

        if ($url =~ m#^/json/(.*)#) {
            my $jsonurl = $1;
#             return 0 if (length($self->{content}) < $self->{headers}->{"content-length"});
            $self->{responseheaders}->{'Content-Type'} = 'application/json';
            if ($self->{headers}->{"content-length"} && !defined $self->{remaining}) {
                $self->{"remaining"} = $self->{headers}->{"content-length"} - length($self->{content});
            }
            $content = encode_json {'status' => 'error', 'error' => sprintf 'unrecognised target or action: %s', $jsonurl};
            if ($jsonurl =~ m#^(\w+)-(\w+)$#) {
                my ($target, $action) = ($1, $2);
#                 printf "Parsing %s:%s\n", $target, $action, $self->{content};
#                 die Dumper Netrap::Parse::actions($target, $action);
                if (my $callback = Netrap::Parse::actions($target, $action)) {
#                     printf "Got callback\n";
                    %object = (%object, 'target' => $target, 'action' => $action, 'status' => 'OK', 'content' => $self->{content} );
#                     die Dumper \$self;
                    if ($self->{content} && $self->{headers}->{'content-type'} =~ m#^application/json\b#) {
                        eval {
                            my $json = decode_json($self->{content});
#                             printf "Got %s\n", Data::Dumper->Dump([$json], [qw'json']) if $json;
                            %object = (%object, %{$json});
                        } or %object = (%object, 'status' => 'error', 'error' => $!);
                    }

#                     print Dumper \%object;
                    my $response = $callback->($self, \%object);
#                     print Dumper $response;

                    if (length($self->{content}) >= $self->{headers}->{"content-length"}) {
                        $response = {%object, 'status' => 'error', 'error' => scalar($response)} unless ref($response) eq 'HASH';
                        delete $response->{content};
                        eval {
                            $content = encode_json $response;
                        }
                        or do {
                            print "Weird data in response:";
                            print Dumper \$response;
                        };
                    }
                    elsif (ref($response) eq 'HASH' && $response->{status} =~ /ok/i) {
#                         printf "Waiting for data\n";
                        $self->{state} = STATE_GET_DATA;
                        if ($response->{UploadManager}) {
                            $response->{UploadManager}->addReceiver('Complete', $self, sub { $self->uploadComplete(\%object); });
                            $self->{UploadManager} = $response->{UploadManager};
                        }
                        if ($response->{UploadFile}) {
#                             $response->{UploadFile}->addReceiver('Write', $self, sub { $self->fireEvent('WroteSomeData') });
                            $self->{UploadFile} = $response->{UploadFile};
#                             $self->addReceiver('Read', $self, sub { print Dumper $self->{UploadManager}; });
#                             $self->sendHeader();
                        }
                        if ($response->{SendHeader}) {
                            $self->sendHeader();
                        }
                        return 0;
                    }
                    else {
                        if (ref($response)) {
                            $content = encode_json $response;
                        }
                        elsif ($response) {
                            $content = $response
                        }
                    }
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
                        # same as qx// except we don't have to sanitise the filename
                        my $pid = open(KID, "-|");
                        if (defined $pid) {
                            if ($pid) {
                                my $mime = <KID>;
                                close KID;
                                if ($mime =~ m#^[\w\-]+/[\w\-]+$#) {
                                    $self->{responseheaders}->{'Content-Type'} = $mime;
                                }
                            }
                            else {
                                exec 'file', '--mime-type', '-b', $local or die $!;
                            }
                        }
                    }
                    $filesocket->raw(1);
                    my $fm = new Netrap::FlowManager();
                    $self->{responseheaders}->{'Content-Length'} = $filesocket->length();
                    $self->{FileSendFlowManager} = $fm;
                    $fm->addSink($self);
                    $fm->addFeeder($filesocket);
                    undef $content;
                    $self->{headers}->{responsecode} = 200;
                    $self->{headers}->{responsedesc} = 'OK';
                    $filesocket->addReceiver('Close', $self, $self->can('fileSendComplete'));

                    $self->sendHeader();
                    $self->{state} = STATE_SEND_DATA;
                    $self->raw(1);

                    my $log = "^remoteaddr;:^remoteport;\t^method; ^url; ^responsecode; ^size;\n";
                    $log =~ s/\^(\w+)\;/$self->{headers}->{$1} || $self->{$1}/eg;
                    print $log;
                    return 1;
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
    if ($self->{headers}->{'connection'} !~ /keep-alive/i) {
        $self->close();
        $self->readline() while $self->canread();
    }

    my $log = "^remoteaddr;:^remoteport;\t^method; ^url; ^responsecode; ^size; ^error;\n";
    $log =~ s/\^(\w+)\;/$self->{headers}->{$1} || $self->{$1} || $object{$1}/eg;
    print $log;

    $self->requestComplete();

    return 1;
}

sub processHTTPData() {
    my $self = shift;
    $self->fireEvent('GotSomeData');
}

sub uploadComplete() {
    my $self = shift;

    my %object = %{(shift)};

    delete $object{content};

    my $content = encode_json(\%object);

    $self->{responseheaders}->{"Content-Length"} = length($content);

    if ($self->sendHeader()) {
        $self->write($content);
    }

    $self->requestComplete();
}

sub requestComplete() {
    my $self = shift;
    my $file = shift;
#     printf "%s: File Send Complete (%s)\n", $self, $file->describe();

    $self->raw(0);
    $self->{state} = STATE_START;
    $self->fireEvent('RequestComplete');

    $self->cullReceivers('GotHeader');
    $self->cullReceivers('GotSomeData');
    $self->cullReceivers('GotAllData');
#     $self->cullReceivers('WroteSomeData');
    $self->cullReceivers('RequestComplete');

    delete $self->{FileSendFlowManager};
    delete $self->{remaining};

#     printf "Connection: %s\n", $self->{headers}->{'connection'};
    if ($self->{headers}->{'connection'} !~ /keep-alive/i) {
#         printf "Closing\n";
        $self->close();
        $self->flushrx();
    }

    $self->{headers} = {};
}

sub readline {
    my $self = shift;
    my $length;

    my $line = $self->SUPER::readline(\$length);

    if ($self->{remaining}) {
        $self->{remaining} -= $length;
    }

    if (@_ && $_[0] && ref($_[0]) eq 'SCALAR') {
        ${$_[0]} = $length;
    }

    return $line;
}

sub fileSendComplete() {
    my $self = shift;

    my $file = shift;
#     printf "%s: File Send Complete (%s)\n", $self, $file->describe();

    $self->requestComplete();
}

sub checkclose {
    my $self = shift;

    my $r = $self->SUPER::checkclose(@_);

    if ($r == 1) {
        delete $HTTPSockets{$self};
    }

    return $r;
}

1;
