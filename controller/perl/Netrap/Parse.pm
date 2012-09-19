package Netrap::Parse;

use strict;

use Data::Dumper;

use Netrap::Socket;
use Netrap::Socket::Printer;

use IO::Termios;

my $upload_dir = 'upload/';

sub socket_list {
    my $requestor = shift;
    my $object = shift;

    $object->{sockets} = [];

    for (values %Netrap::Socket::sockets) {
        push @{$object->{sockets}}, $_->describe();
    }

    return $object;
}

sub printer_add {
    my $requestor = shift;
    my $object = shift;

    my $device;
    my $port;
    my $baud;

    if (ref($object)) {
        $device = $object->{device};
        $port = $object->{port};
        $baud = $object->{baud};
    }
    elsif ($object =~ /^(\S+)\s+(\d+)$/) {
        $device = $1;
        my $num = $2;
        if ($device =~ m#^/# || $device =~ m#^com\d+#) {
            $baud = $num;
        }
        else {
            $port = $num;
        }
    }
    if ($port) {
        printf "Connecting to TCP printer at %s:%d\n", $device, $port;
        my $sock = new IO::Socket::INET(PeerAddr => $device, PeerPort => $port, Proto => 'tcp', Blocking => 0) or return "error: $!";
        my $newprinter = new Netrap::Socket::Printer($sock);
        $newprinter->{name} = sprintf "TCP:%s:%d", $device, $port;
        printf "Printer %s Created\n", $newprinter->{name};
        return {"printer" => $newprinter->{name}};
    }
    else {
#         printf "Could not connect to %s %d\n", $device, $baud;
        printf "Connecting to Serial printer at %s @%d\n", $device, $baud;
        my $sock = IO::Termios->open($device) or return "error: $!";
        if ($sock) {
            $sock->setbaud($baud);
            $sock->setcsize(8);
            $sock->setparity("n");
            $sock->setstop(1);
            my $newprinter = new Netrap::Socket::Printer($sock);
            $newprinter->{name} = sprintf "SERIAL:%s @%d", $device, $baud;
            printf "Printer %s Created\n", $newprinter->{name};
            return {%{$object}, "printer" => $newprinter->{name}};
        }
        die Dumper \$sock;
    }
    return %{$object};
}

sub printer_list {
    my $requestor = shift;
    my $object = shift;

    $object->{printers} = [];

    for (keys %Netrap::Socket::Printer::PrinterSockets) {
        my $printer = $Netrap::Socket::Printer::PrinterSockets{$_};
        push @{$object->{printers}}, $printer->{name};
    }
    $object->{printercount} = @{$object->{printers}};
    return $object;
}

sub printer_load {
    my $requestor = shift;
    my $object = shift;
}

sub printer_pause {
    my $requestor = shift;
    my $object = shift;
}

sub printer_resume {
    my $requestor = shift;
    my $object = shift;
}

sub printer_restart {
    my $requestor = shift;
    my $object = shift;
}

sub printer_stop {
    my $requestor = shift;
    my $object = shift;
}

sub printer_query {
    my $requestor = shift;
    my $object = shift;
    my @lines = split /\r?\n/, $object->{content};
    print "Enqueue:\n";
    print "\t$_\n" for @lines;
}

sub printer_select {
    my $requestor = shift;
    my $object = shift;
    my $printername;

    if (ref($object)) {
        $printername = $object->{printer};
    }
    else {
        $printername = $object;
    }

#     print "Looking for $printername\n";

    my @matches = grep {$_->{name} =~ m#\Q$printername\E#} values %Netrap::Socket::Printer::PrinterSockets;;
    if (@matches == 1) {
#         printf "requestor printer is %s\n", $requestor->{printer};
        $requestor->{printer}->{FlowManager}->removeFeeder($requestor) if $requestor->{printer};
        $requestor->{printer} = $matches[0];
        $requestor->{printer}->{FlowManager}->addFeeder($requestor);
#         printf "Found %s\n", $matches[0]->{name};
        return {"printer" => $matches[0]->{name} };
    }
    if (@matches > 1) {
#         print sprintf "error: %d names match requested string\n", scalar @matches;
        return sprintf "error: %d names match requested string", scalar @matches;
    }
#     print "No matches";
    return "No matches";
}

sub printer_dump {
    my $requestor = shift;
    my $object = shift;

    print Dumper \($requestor->{printer} or %Netrap::Socket::Printer::PrinterSockets);

    return $requestor->{printer} or %Netrap::Socket::Printer::PrinterSockets;
}

sub file_load {
    my $requestor = shift;
    my $object = shift;

}

sub file_list {
    my $requestor = shift;
    my $object = shift;
    opendir D, $upload_dir or die $!;
    my @l = readdir D;
    closedir D;

    my @r;

    for (@l) {
        if (!m#^\.\.?$#) {
            my $filename = $upload_dir.$_;
            my %f = ('name' => $_);
            $f{type} = 'directory' if -d $filename;
            $f{type} = 'file' if -f $filename;
            $f{size} = (stat(_))[7];
            push @r, \%f if $f{type};
        }
    }
    return {%{$object}, 'files' => \@r};
}

sub file_upload {
    my $requestor = shift;
    my $object = shift;
}

sub file_describe {
    my $requestor = shift;
    my $object = shift;
}

sub file_delete {
    my $requestor = shift;
    my $object = shift;
    return {%{$object}, 'status' => 'error', 'error' => 'bad filename'} if $object->{file} =~ /(\.\.\/|\/\.\.)/;
    unlink $upload_dir.$object->{file} if -r $upload_dir.$object->{file};
    return $object;
}

my %actions = (
    'socket' => {
        'list' => \&socket_list,
    },
    'printer' => {
        'add' => \&printer_add,
        'list' => \&printer_list,
        'load' => \&printer_load,
        'pause' => \&printer_pause,
        'resume' => \&printer_resume,
        'restart' => \&printer_restart,
        'stop' => \&printer_stop,
        'query' => \&printer_query,
        'select' => \&printer_select,
        'use' => \&printer_select,
        'dump' => \&printer_dump,
    },
    'file' => {
        'load' => \&file_load,
        'list' => \&file_list,
        'upload' => \&file_upload,
        'describe' => \&file_describe,
        'delete' => \&file_delete,
    },
);

sub targets {
    my $target = shift;
    if ($target) {
        return grep {/\Q$target\E/} keys %actions;
    }
    return keys %actions;
}

sub actions {
    my $target = shift or return undef;
    my $action = shift or return undef;

    return $actions{$target}->{$action} if $actions{$target} && $actions{$target}->{$action};
    return undef;
}

