package Netrap::Parse;

use strict;

use Data::Dumper;

use Netrap::Socket;
use Netrap::Socket::Printer;

my $upload_dir = 'upload/';

sub socket_list {
}

sub printer_add {
}

sub printer_list {
    my $object = shift;
#     die sprintf "%s:%s from %s", $target, $action, $source;

    $object->{printers} = [
        {name=>'blah',address=>'here'},
    ];

    for (keys %Netrap::Socket::Printer::PrinterSockets) {
        my $printer = $Netrap::Socket::Printer::PrinterSockets{$_};
        push @{$object->{printers}}, [$printer->{name}, $printer->{address}];
    }
    $object->{printercount} = @{$object->{printers}};
    return $object;
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
}

sub file_describe {
}

sub file_delete {
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
    },
    'file' => {
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

    return $actions{$target}->{$action};
}

