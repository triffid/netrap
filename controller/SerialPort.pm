# Lets serial port programs written for either Windows or Unix
# work on the other kind of system without modification.
# By Ned Konz, ned@bike-nomad.com, http://bike-nomad.com
# This script must have only LF line endings to work cross-platform.
# usage:
#  perl -MAnySerialPort myProgram.pl
#
# This will map port names between Linux and Windows; if your system doesn't
# use the same mappings, you can call
# Device::SerialPort::mapPorts
# or
# Win32::SerialPort::mapPorts
# to change it:
# Device::SerialPort->mapPorts('COM1:' => '/dev/magicSerial0',
#         'COM2' => '/dev/magicSerial1');

package SerialPort;

use strict;
use vars '@ISA';

BEGIN
{
 my %portMap;
 my $oldNew;
 my $onWindows = 0;

 if ($^O eq 'MSWin32') # running on Win32
 {
  $onWindows = 1;
  eval "use Win32::SerialPort";
  *main::Device::SerialPort:: = *main::Win32::SerialPort::;
  $oldNew = \&Win32::SerialPort::new;
  $INC{'Device/SerialPort.pm'} = $INC{'Win32/SerialPort.pm'};
  %portMap = ('/dev/ttyS0' => 'COM1:',
     '/dev/ttyS1' => 'COM2:',
     '/dev/ttyS2' => 'COM3:',
     '/dev/ttyS3' => 'COM4:',
    );
 }
 else # running on Unix
 {
  eval "use Device::SerialPort";
  *main::Win32::SerialPort:: = *main::Device::SerialPort::;
  $oldNew = \&Device::SerialPort::new;
  $INC{'Win32/SerialPort.pm'} = $INC{'Device/SerialPort.pm'};
  %portMap = ('COM1:'=> '/dev/ttyS0',
     'COM2:'=> '/dev/ttyS1',
     'COM3:'=> '/dev/ttyS2',
     'COM4:'=> '/dev/ttyS3',
    );
 }

 die "$@\n" if $@;
 @ISA = 'Device::SerialPort';

 # Hook the constructor so we can map the port names
 # and class if needed
 *main::Device::SerialPort::new = sub {
  my $class = shift;
  my $portName = shift;
  if ($onWindows != ($class eq 'Win32::SerialPort'))
  {
   $portName = $portMap{$portName} || $portName;
   $class = $onWindows ? 'Win32::SerialPort' : 'Device::SerialPort';
  }
  $oldNew->($class, $portName, @_);
 };

 # Gets and/or modifies the port mapping
 # Returns a hash
 sub Device::SerialPort::mapPorts
 {
  my $self = shift;
  %portMap = (%portMap, @_);
 }
}

1;
