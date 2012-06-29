#!/usr/bin/perl

use strict;

use Device::SerialPort;
use IO::Select;
use IO::Socket::INET;
use JSON::PP;

use Data::Dumper;

my $httpport = 2560;
my $netrapport = 2561;

my $filesdir = 'html';
my $uploaddir = 'html/upload';

my $HTTPListenSocket = new IO::Socket::INET(LocalAddr => '0.0.0.0', LocalPort => $httpport, Proto => 'tcp', Listen => 8, ReuseAddr => 1, Blocking => 0) or die $!;
my %HTTPListenSockets = ($HTTPListenSocket => {sock => $HTTPListenSocket});

my $NetRapListenSocket = new IO::Socket::INET(LocalPort => $netrapport, Proto => 'tcp', Listen => 8, ReuseAddr => 1, Blocking => 0) or die $!;
my %NetRapListenSockets = ($NetRapListenSocket => {sock => $NetRapListenSocket});

my %HTTPSockets;
my %NetRapSockets;
my %PrinterSockets;
my %FileSockets;

my %sockets;

my $ReadSelector = new IO::Select();
my $WriteSelector = new IO::Select();
my $ErrorSelector = new IO::Select();

sub new_socket {
	my $newsocket = shift;
	my $type = shift;
	$sockets{$newsocket} = {
		sock => $newsocket,
		type => $type,
		rxbuffer => "",
		read => 0,
		rxqueue => [],
		txbuffer => "",
		written => "",
		close => 0,
		txqueue => [],
		};
	$newsocket->autoflush(1);
	$newsocket->blocking(0);
	return $sockets{$newsocket};
}

sub new_HTTPSocket {
	my $newsocket = shift;
	my $address = shift;
	my $sock = new_socket($newsocket, 'http');
	$HTTPSockets{$newsocket} = $sock;
	$sock->{rawaddr}         = $address;
	$sock->{remoteaddr}      = join(".", (unpack('SnCCCC', $address))[2,3,4,5]);
	$sock->{remoteport}      = (unpack('SnCCCC', $address))[1];
	$sock->{name}            = sprintf "%s:%d", $sock->{remoteaddr}, $sock->{remoteport};
	$sock->{endofheaders}    = 0;
	$sock->{replies}         = [];
	return $sock;
}

sub new_NetRapSocket {
	my $newsocket = shift;
	my $address = shift;
	my $sock = new_socket($newsocket, 'netrap');
	$NetRapSockets{$newsocket} = $sock;
	$sock->{rawaddr}         = $address;
	$sock->{remoteaddr}      = join(".", (unpack('SnCCCC', $address))[2,3,4,5]);
	$sock->{remoteport}      = (unpack('SnCCCC', $address))[1];
	$sock->{name}            = sprintf "%s:%d", $sock->{remoteaddr}, $sock->{remoteport};
	$sock->{replies}         = [];
	return $sock;
}

sub new_PrinterSocket {
	my $printer = shift;
	my $sock = new_socket($printer, 'printer');
	my $device = shift;
	$PrinterSockets{$printer} = $sock;
	$sock->{device}   = $device;
	$sock->{name}     = $device;
	$sock->{linesw}   = 0;
	$sock->{token}    = 1;
	$sock->{txbuffer} = "M115\nM114\nM503\n";
	$sock->{name}     = $device;
	return $sock;
}

sub new_FileSocket {
	my $file = shift;
	my $sock = new_socket($file, 'file');
	my $name = shift;
	my $path = shift;
	$FileSockets{$file} = $sock;
	$sock->{file} = $file;
	$sock->{name} = $name;
	$sock->{path} = $path;
	$sock->{readbytes} = 0;
	$sock->{totalbytes} = -s $path;
	$sock->{paused} = 1;
	return $sock;
}

sub findPrinterByName {
	my $name = shift;
	for my $printer (keys %PrinterSockets) {
		if ($PrinterSockets{$printer}->{name} eq $name) {
			return $PrinterSockets{$printer};
		}
	}
	return undef;
}

sub jsonResponse {
	my $sock = shift;
	my $obj = shift;
	my $s = $sock->{sock};
	my $json = encode_json($obj) . "\n";
	$sock->{txbuffer} .= sprintf("HTTP/1.1 200 OK\nContent-Type: application/json\nConnection: close\nContent-Length: %d\n\n%s", length($json), $json);
	$WriteSelector->add($s);
	$ReadSelector->remove($s);
	$sock->{close} = 1;
}

sub jsonError {
	my $sock = shift;
	my $errormsg = shift;
	my $s = $sock->{sock};
	my $json = encode_json({'status' => 'failure', 'error' => $errormsg}) . "\n";
	$sock->{txbuffer} .= sprintf("HTTP/1.1 400 Bad Request\nContent-Type: application/json\nConnection: close\nContent-Length: %d\n\n%s", length($json), $json);
	$WriteSelector->add($s);
	$ReadSelector->remove($s);
	$sock->{close} = 1;
}

sub plainError {
	my $sock = shift;
	my $errormsg = shift;
	my $s = $sock->{sock};
	$sock->{txbuffer} .= sprintf("HTTP/1.1 400 Bad Request\nContent-Type: text/plain\nConnection: close\n\nError: %s\n", $errormsg);
	$WriteSelector->add($s);
	$ReadSelector->remove($s);
	$sock->{close} = 1;
}

sub parseLine {
	my ($sock, $s, $line) = @_;
	my $printer = $sock->{printer};
	my $r = length($line);
	if ($line =~ /^([A-Z][\d\.]*\s*)+$/) {
		# looks like gcode
		if ($sock->{printer}) {
			$sock->{printer}->{requestor} = $sock;
			$sock->{printer}->{txbuffer} .= "$line\n";
			$WriteSelector->add($sock->{printer}->{sock});
			$sock->{count}++;
		}
	}
	elsif ($line =~ /^(select|printer)\s+(\S+)$/) {
		my $printername = $2;
		chomp $printername;
		$printer = findPrinterByName($printername);
		#printf "%s: Printer %s selected.\n", $sock->{name}, $sock->{printer}->{name};
		if (defined $printer) {
			$sock->{printer} = $printer;
		}
		else {
			printf "%s: Printer %s not found.\n", $sock->{name}, $printername;
			push @{$sock->{replies}}, sprintf "Printer %s not found.", $printername;
		}
	}
	else {
		if ($sock->{printer}) {
			$sock->{printer}->{requestor} = $sock;
			$sock->{printer}->{txbuffer} .= "$line\n";
			$WriteSelector->add($sock->{printer}->{sock});
			$sock->{count}++;
		}
	}
	return $r;
}

for my $s (values %HTTPListenSockets, values %NetRapListenSockets) {
	$ReadSelector->add($s->{sock});
	$ErrorSelector->add($s->{sock});
}

while (1) {
	my ($readsocket, $writesocket, $errorsocket) = IO::Select::select($ReadSelector, $WriteSelector, $ErrorSelector, undef);
	my @readsocket = @$readsocket;
	my @writesocket = @$writesocket;
	my @errorsocket = @$errorsocket;

	for my $s (@errorsocket) {
		if ($sockets{$s}) {
			$sockets{$s}->{close} = 1;
			$WriteSelector->add($s);
		}
		else {
			close $s;
		}
	}

	for my $s (@readsocket) {
		if (exists $HTTPListenSockets{$s}) {
			my ($newsocket, $address) = $s->accept();
			new_HTTPSocket($newsocket, $address);
			$newsocket->blocking(0);
			$ReadSelector->add($newsocket);
		}
		elsif (exists $NetRapListenSockets{$s}) {
			my ($newsocket, $address) = $s->accept();
			new_NetRapSocket($newsocket, $address);
			$newsocket->blocking(0);
		}
		elsif (exists $HTTPSockets{$s}) {
			my $sock = $HTTPSockets{$s};
			my $buf;
			my $r = $s->sysread($buf, 1024);
			$sock->{rxbuffer} .= $buf;
			$sock->{read} += $r;
# 			printf "READ:'%s'\n", $sock->{rxbuffer};
			if ($r == 0) {
				# socket closed
				$ReadSelector->remove($s);
				$WriteSelector->remove($s);
				$ErrorSelector->remove($s);
				delete $HTTPSockets{$s};
				delete $sockets{$s};
			}
			else {
				if (($sock->{endofheaders} == 0) && ($sock->{rxbuffer} =~ /^([A-Z]+)\s+(\/\S*)\s+HTTP\/([\d\.]+).*\r?\n\r?\n/is)) {
					my %request = (
						'method' => $1,
						'uri' => $2,
						'version' => $3,
					);
					# consume headers from rx buffer in case content follows
					$sock->{rxbuffer} =~ s/^.*?\r?\n//is;
					while ($sock->{rxbuffer} =~ s/^([\w\-]+)\s*:\s*(.*?)\r?\n//is) {
						$request{uc $1} = $2;
					}
					$sock->{rxbuffer} =~ s/^\r?\n//ms;
					printf "%s\t%s %s\n", $sock->{remoteaddr}, $request{method}, $request{uri};
					$sock->{request} = \%request;
					$sock->{endofheaders} = 1;
				}
				if ($sock->{request}) {
					my $request = $sock->{request};
					# look for /.. or ../ in URI
					$request->{uri} = '/index.html'
						if $request->{uri} eq '/' && -r $filesdir.'/index.html';
					if ($request->{uri} =~ /\/\.\./ || $request->{uri} =~ /\.\.\//) {
						plainError($sock, "../ or /.. not allowed in URI");
					}
					elsif ($request->{uri} =~ /^\/json\/(\S+)/) {
						# TODO: parse json request
						my $jsonuri = $1;
						my %parameters;
						$sock->{jsonuri} = $jsonuri;
						if ($jsonuri =~ s/\?(.*)//) {
							my $parameters = $1;
							for my $pair (split /&/, $parameters) {
								my $value;
								if ($pair =~ s/=(.*)//) {
									$value = $1;
								}
								$parameters{$pair} = $value;
							}
						}
						for ($jsonuri) {
							/^sockets$/ && do {
								$sock->{txbuffer} = sprintf("HTTP/%s 200 OK\nContent-Type: application/json\nConnection: Close\n\n[", $sock->{version});
								for my $so (values %sockets) {
									$sock->{txbuffer} .= sprintf("{'remoteaddr':'%s','remoteport':%d,},", $so->{remoteaddr}, $so->{remoteport});
								}
								$sock->{txbuffer} .= "]\n";
								$sock->{'close'} = 1;
								$WriteSelector->add($s);
								$ReadSelector->remove($s);
								last;
							};
							/^(enqueue|query)$/ && do {
								$sock->{count} = 0;
								$request->{'CONTENT-LENGTH'} = 0 unless $request->{'CONTENT-LENGTH'};
								if (!defined $sock->{headers}) {
									$sock->{txbuffer} = sprintf("HTTP/%s 200 OK\nContent-type: application/json\nConnection: Close\n\n{\"status\":\"success\",\"replies\":[", $request->{version});
									$WriteSelector->add($s);
									$ReadSelector->remove($s);
									$sock->{headers} = 1;
								}
								while ($sock->{rxbuffer} =~ s/^(\s*(.*?)\s*\r?\n)//is) {
									my $line = $2;
									$sock->{replies} = [] unless $sock->{replies};
									if ($line =~ /^(select|printer)\s+(\S+)$/) {
										my $printername = $2;
# 										for my $printer (keys %PrinterSockets) {
# 											my $psock = $PrinterSockets{$printer};
# 											if ($psock->{name} eq $printername) {
# 												$sock->{printer} = $psock;
# 												printf "%s: Printer %s selected.\n", $sock->{name}, $psock->{name};
# # 												push @{$sock->{replies}}, sprintf "Printer %s selected.", $psock->{name};
# 												last;
# 											}
# 										}
										$sock->{printer} = findPrinterByName($printername);
										#printf "%s: Printer %s selected.\n", $sock->{name}, $sock->{printer}->{name};
										if (! defined $sock->{printer}) {
											printf "%s: Printer %s not found.\n", $sock->{name}, $printername;
											push @{$sock->{replies}}, sprintf "Printer %s not found.", $printername;
										}
									}
									else {
	# 									printf "\"%s\": %d bytes\n", $1, length($1);
										$request->{'CONTENT-LENGTH'} -= length($1);
										# TODO: enqueue $line;
# 										printf "ENQUEUE:\t%s\n", $line;
										if ($sock->{printer}) {
											$sock->{printer}->{requestor} = $sock;
											$sock->{printer}->{txbuffer} .= "$line\n";
											$WriteSelector->add($sock->{printer}->{sock});
											$sock->{count}++;
										}
	# 									printf "%s: %d\n", $sock->{remoteaddr}, $sock->{count};
									}
								}
								if (@{$sock->{replies}}) {
									my $reply = pop @{$sock->{replies}};
									chomp $reply;
									$reply =~ s/"/\\"/g;
									$sock->{txbuffer} .= '"'.$reply.'",';
									$WriteSelector->add($s);
									$sock->{count}-- if $reply =~ /^ok\b/;
									if ($sock->{count} <= 0) {
										$sock->{txbuffer} =~ s/,$//m;
										$sock->{txbuffer} .= "]}\n";
										$sock->{close} = 1;
										$WriteSelector->add($s);
									}
									printf "%s: *%d\n", $sock->{remoteaddr}, $sock->{count};
								}
# 								printf "%s: %d\n", $sock->{remoteaddr}, $sock->{count};
								last;
							};
							/^printer$/ && do {
								$request->{'CONTENT-LENGTH'} = 0 unless $request->{'CONTENT-LENGTH'};
# 								printf("content length: %d\n", $request->{'CONTENT-LENGTH'});
								if (length($sock->{rxbuffer}) >= $request->{'CONTENT-LENGTH'}) {
									my $obj = decode_json($sock->{rxbuffer});
									my $printer;
									if (($obj->{device} =~ /[\w\d]/) && (exists $obj->{port}) && do { printf "Trying to connect to %s:%d...\n", $obj->{device}, $obj->{port}; 1;} && ($printer = new IO::Socket::INET(PeerAddr => $obj->{device}, PeerPort => $obj->{port}, Proto => 'tcp'))) {
										my $psck = new_PrinterSocket($printer, sprintf("%s:%d", $obj->{device}, $obj->{port}));
										$psck->{port} = $obj->{port};
										$WriteSelector->add($printer);
										$psck->{address} = sprintf "%s:%d", $obj->{device}, $obj->{port};
										printf "Added printer %s:%d\n", $obj->{device}, $obj->{port};
# 										$sock->{txbuffer} .= sprintf("HTTP/%s 200 OK\nContent-Type: application/json\nConnection: close\n\n{\"status\":\"success\"}\n", $request->{version});
# 										$WriteSelector->add($s);
										$WriteSelector->add($printer);
# 										$sock->{close} = 1;
										jsonResponse($sock, {"status" => "success", "name" => $psck->{name}});
									}
									elsif (($obj->{device} =~ /[\w\d]/) && (exists $obj->{baud}) && ($printer = new Device::SerialPort($obj->{device}))) {
										$printer->baudrate($obj->{baud});
										$printer->databits(8);
										$printer->parity("none");
										$printer->stopbits(1);
										$printer->handshake("xoff");
										$printer->write_settings();
										$printer->read_const_time(0);
										$printer->read_char_time(0);
										$printer->close;
										undef $printer;

										open($printer, '+<', $obj->{device}) or die $!;

										my $psck = new_PrinterSocket($printer, $obj->{device}, $obj->{baud});
										$psck->{address} = sprintf "%s@%d", $obj->{device}, $obj->{baud};
										$WriteSelector->add($printer);

										printf "Added printer %s @%d\n", $obj->{device}, $obj->{baud};
# 										$sock->{txbuffer} .= sprintf("HTTP/%s 200 OK\nContent-Type: application/json\nConnection: close\n\n{\"status\":\"success\"}\n", $request->{version});
# 										$WriteSelector->add($s);
# 										$sock->{close} = 1;
										jsonResponse($sock, {'status' => 'success', 'name' => $psck->{name}});
									}
									else {
# 										printf("failed: $!\n");
# 										$sock->{txbuffer} .= sprintf("HTTP/%s 200 OK\nContent-Type: application/json\nConnection: close\n\n{\"status\":\"failure\",\"error\":\"%s\"}\n", $request->{version}, $!);
# 										$WriteSelector->add($s);
# 										$sock->{close} = 1;
										jsonError($sock, $!);
									}
								}
							};
							/^printer-list$/ && do {
								$sock->{txbuffer} .= sprintf "HTTP/%s 200 OK\nContent-Type: application/json\nConnection: close\n\n{\"printercount\":%d,\"printers\":[", $request->{version}, (scalar keys %PrinterSockets);
								for my $printer (keys %PrinterSockets) {
									$sock->{txbuffer} .= sprintf "{\"name\":\"%s\",\"address\":\"%s\"},", $PrinterSockets{$printer}->{name}, $PrinterSockets{$printer}->{address};
								}
								$sock->{txbuffer} =~ s/,$//m;
								$sock->{txbuffer} .= "]}";
								$WriteSelector->add($s);
								$sock->{close} = 1;
							};
							/^printer-resume$/ && do {
								$request->{'CONTENT-LENGTH'} = 0 unless $request->{'CONTENT-LENGTH'};
								if (length($sock->{rxbuffer}) >= $request->{'CONTENT-LENGTH'}) {
									my $obj = decode_json($sock->{rxbuffer});
									my $printer = findPrinterByName($obj->{printer});
									if ($printer) {
										if ($printer->{openfile}) {
											$printer->{openfile}->{paused} = 0;
											$WriteSelector->add($printer->{sock});
											jsonResponse($sock, {status => 'success'});
										}
										else {
											jsonError($sock, {status => 'failure', error => 'no file loaded for this printer'});
										}
									}
									else {
										jsonError($sock, sprintf "printer %s not found", $obj->{printer});
									}
								}
							};
							/^printer-pause$/ && do {
								$request->{'CONTENT-LENGTH'} = 0 unless $request->{'CONTENT-LENGTH'};
								if (length($sock->{rxbuffer}) >= $request->{'CONTENT-LENGTH'}) {
									my $obj = decode_json($sock->{rxbuffer});
									my $printer = findPrinterByName($obj->{printer});
									if ($printer) {
										if ($printer->{openfile}) {
											$printer->{openfile}->{paused} = 1;
										}
									}
								}
							};
							/^file-open$/ && do {
								$request->{'CONTENT-LENGTH'} = 0 unless $request->{'CONTENT-LENGTH'};
								if (length($sock->{rxbuffer}) >= $request->{'CONTENT-LENGTH'}) {
									my $obj = decode_json($sock->{rxbuffer});
									my $name = $obj->{name};
									my $path = $uploaddir.'/'.$parameters{name};
									my $start = $obj->{start} or 0;
									my $file;
									if ($name !~ /[\/\|]/) {
										if ((-r $path) && (open($file, '<', $path))) {
											my $fsock = new_FileSocket($file, $name, $path);
											if ($obj->{printer}) {
												$fsock->{printer} = findPrinterByName($obj->{printer});
												$fsock->{printer}->{openfile} = $fsock;
											}
											jsonResponse($sock, {status => 'success', name => $name, 'length' => -s $path});
										}
										else {
											jsonError($sock, "file not found");
										}
									}
									else {
										printf("failed: $!\n");
# 										$sock->{txbuffer} .= sprintf("HTTP/%s 200 OK\nContent-Type: application/json\nConnection: close\n\n{\"status\":\"failure\",\"error\":\"%s\"}\n", $request->{version}, "Invalid characters in filename");
# 										$WriteSelector->add($s);
# 										$sock->{close} = 1;
										jsonError($sock, "Invalid characters in filename");
									}
								}
							};
							/^file-upload$/ && (exists $parameters{name}) && do {
								if (!exists $sock->{file}) {
									my $startbyte = $parameters{start} or 0;
									my $endbyte = $startbyte + $request->{'CONTENT-LENGTH'};
									my $name = $parameters{name};
									printf "File Upload: %s (%d+%d = %d)s\n", $name, $startbyte, $endbyte, $endbyte - $startbyte;
									my $path = $uploaddir . '/' . $name;
									if ($name !~ /^[a-z0-9]/i || $name =~ /[\/\|]/) {
										$! = "invalid filename";
									}
									elsif (open($sock->{file}, '+>>', $path)) {
										seek $sock->{file}, $startbyte, Fcntl::SEEK_SET;
										$sock->{filename} = $name;
										$sock->{filepath} = $path;
										$sock->{start} = $startbyte;
										$sock->{end} = $endbyte;
										$sock->{written} = 0;
										$sock->{remaining} = $endbyte - $startbyte;

									}
									if (!exists $sock->{file}) {
										printf("failed: $!\n");
										jsonError($sock, $!);
									}
								}
								if ($sock->{file}) {
									my $written = $sock->{file}->syswrite($sock->{rxbuffer});
									substr($sock->{rxbuffer}, 0, $written, "");
									$sock->{written} += $written;
									$sock->{remaining} -= $written;
									printf "Wrote %d to %s, %d remains\n", $written, $sock->{filename}, $sock->{remaining};
									if ($sock->{remaining} <= 0) {
										undef $sock->{file};
# 										$sock->{txbuffer} .= sprintf("HTTP/%s 200 OK\nContent-Type: application/json\nConnection: close\n\n{\"status\":\"success\",\"filename\":\"%s\",\"start\":%d,\"end\":%d,\"written\":%d,\"length\":%d}\n", $request->{version}, $sock->{filename}, $sock->{start}, $sock->{end}, $sock->{written}, -s $sock->{filepath});
										jsonResponse($sock, {
												'status'   => 'success',
												'filename' => $sock->{filename},
												'start'    => $sock->{start},
												'end'      => $sock->{end},
												'written'  => $sock->{written},
												'length'   => -s $sock->{filepath},
											});
									}
								}
							}
						}
					}
					elsif (-r $filesdir.$request->{uri}) {
						# read a local file
						my $file;
						if (open $file, '<', $filesdir.$request->{uri}) {
							my $ext = $request->{uri}; $ext =~ s/.*\.//;
							my %extensions = (
								html => 'text/html',
								js => 'text/javascript',
								css => 'text/css'
								);
							my $mimetype = $extensions{$ext} or qx:file -b --mime-type "$filesdir$request->{uri}": or 'text/plain';
							chomp $mimetype;
							$sock->{txbuffer} = sprintf("HTTP/%s 200 OK\nContent-Length: %d\nContent-Type: %s\nConnection: Close\n\n", $request->{version}, -s $filesdir.$request->{uri}, $mimetype);
							$WriteSelector->add($s);
							$ReadSelector->remove($s);
							$sock->{file} = $file;
							$sock->{'close'} = 1;
						}
						else {
							$sock->{txbuffer} = sprintf("HTTP/%s 403 Forbidden\nConnection: Close\n\n", $request->{version});
							$WriteSelector->add($s);
							$ReadSelector->remove($s);
							$sock->{'close'} = 1;
						}
					}
				}
			}
		}
		elsif (exists $NetRapSockets{$s}) {
		}
		elsif (exists $PrinterSockets{$s}) {
			my $sock = $PrinterSockets{$s};
			my $buf;
			my $r = $s->sysread($buf, 4096);
			my $displaybuf = $buf; chomp $displaybuf;
			printf "(%3d)[%s]< %s [in reply to: %s]\n", $r, $sock->{device}, $displaybuf, $sock->{lastline};
			$sock->{rxbuffer} .= $buf;
			$sock->{read} += $r;
			if ($r == 0) {
				# TODO: handle printer disconnection
				$sock->{close} = 1;
				$WriteSelector->add($s);
			}
			while ($sock->{rxbuffer} =~ s/^(.*?)\r?\n//s) {
				my $reply = $1;
				if ($sock->{requestor}) {
					$sock->{requestor} = [] unless $sock->{requestor};
					push @{$sock->{requestor}->{replies}}, $reply;
					$WriteSelector->add($sock->{requestor}->{sock});
				}
				if ($reply =~ /^ok\b/) {
					$sock->{token}++;
					$sock->{lastline} = "";
					if (length($sock->{txbuffer})) {
						$WriteSelector->add($s);
					}
					else {
						# TODO: find all sockets wanting to write to this printer
					}
				}
			}
		}
		elsif (exists $FileSockets{$s}) {
			my $sock = $FileSockets{$s};
			if ($sock->{printer}) {
				if (! $sock->{paused}) {
					my $f = $sock->{file};
					my $buf = <$f>;
					chomp $buf;
					undef $sock->{printer}->{requestor};
					$sock->{printer}->{txbuffer} .= "$buf\n";
					$WriteSelector->add($sock->{printer}->{sock});
					$sock->{printer}->{openfile} = $sock;
				}
				$ReadSelector->remove($s);
			}
		}
	}

	for my $s (@writesocket) {
		my $sock = $sockets{$s};
		my $written = 0;
		my $sentdata = "";
		if ($sock) {
			# general stuff common to all sockets
			if (length($sock->{txbuffer})) {
				$written = $s->syswrite($sock->{txbuffer});
				$sentdata = substr($sock->{txbuffer}, 0, $written, "");
				$sock->{written} += $written;
			}
			# check again, we may have emptied the buffer above
			if (length($sock->{txbuffer}) == 0) {
				if (@{$sock->{txqueue}}) {
					my $item = shift @{$sock->{txqueue}};
					my ($line, $requestor) = @{$item};
					$sock->{txbuffer} .= "$line\n";
					$sock->{requestor} = $requestor;
				}
				elsif ($sock->{close}) {
					$ReadSelector->remove($s);
					$WriteSelector->remove($s);
					$ErrorSelector->remove($s);
					$s->close();
					delete $HTTPSockets{$s} if exists $HTTPSockets{$s};
					delete $NetRapSockets{$s} if exists $NetRapSockets{$s};
					delete $PrinterSockets{$s} if exists $PrinterSockets{$s};
					delete $sockets{$s};
				}
				else {
					$WriteSelector->remove($s);
				}
			}
		}
		if (exists $HTTPSockets{$s}) {
			if ((length($sock->{txbuffer}) == 0) && ($sock->{file})) {
				my $buf;
				my $r = sysread($sock->{file}, $buf, 4096);
				$sock->{txbuffer} .= $buf;
				if ($r == 0) {
					close $sock->{file};
					delete $sock->{file};
				}
			}
			if (@{$sock->{replies}}) {
				my $reply = pop @{$sock->{replies}};
				chomp $reply;
				$reply =~ s/"/\\"/g;
				$sock->{txbuffer} .= '"'.$reply.'",';
				$sock->{count}-- if $reply =~ /^ok\b/;
# 				printf "%s: #%d", $sock->{remoteaddr}, $sock->{count};
				if ($sock->{count} <= 0) {
# 					print ", closing";
					$sock->{txbuffer} =~ s/,$//m;
					$sock->{txbuffer} .= "]}\n";
					$sock->{close} = 1;
					undef $sock->{printer}->{requestor};
				}
# 				print "\n";
				$WriteSelector->add($s);
			}
		}
		elsif (exists $NetRapSockets{$s}) {
			if ($written) {
				$ReadSelector->add($s);
			}
		}
		elsif (exists $PrinterSockets{$s}) {
			if ($written) {
				printf "(%3d)[%s]> %s", $written, $sock->{device}, $sentdata;
				if ($sentdata =~ /\n/) {
					$sock->{linesw}++;
					$ReadSelector->add($s);
					$sock->{token}--;
					if (($sock->{token} <= 0) || ($sock->{txbuffer} !~ /\n/s)) {
						$WriteSelector->remove($s);
					}
					chomp $sentdata;
					$sock->{lastline} .= $sentdata;
				}
				else {
					$sock->{lastline} .= $sentdata;
				}
			}
			elsif (($sock->{openfile}) && (!$sock->{openfile}->{paused})) {
				$ReadSelector->add($sock->{openfile}->{sock});
				$WriteSelector->remove($s);
			}
			else {
				# nothing to write, but not time to close either
				$WriteSelector->remove($s);
			}
		}
		else {
			printf "Unknown socket %s!\n", $s;
			$WriteSelector->remove($s);
		}
	}
}
