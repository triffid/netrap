package Netrap::Parse;

use strict;

use Data::Dumper;

use Netrap::Socket;
use Netrap::Socket::Printer;

sub socket_list {
}

sub printer_add {
}

sub printer_list {
    my $object = shift;
#     die sprintf "%s:%s from %s", $target, $action, $source;

    my $r = {
        printercount => (scalar keys %Netrap::Socket::Printer::PrinterSockets) + 1,
        printers => [
            {name=>'blah',address=>'here'},
        ],
    };

    for (keys %Netrap::Socket::Printer::PrinterSockets) {
        my $printer = $Netrap::Socket::Printer::PrinterSockets{$_};
        push @{$r->{printers}}, [$printer->{name}, $printer->{address}];
    }
    return $r;
}

sub printer_load {
}

sub printer_pause {
}

sub printer_resume {
}

sub printer_restart {
}

sub printer_stop {
}

sub file_list {
}

sub file_upload {
}

sub file_describe {
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
    },
    'file' => {
        'list' => \&file_list,
        'upload' => \&file_upload,
        'describe' => \&file_describe,
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

    return $actions{$target}->{$action};
}

